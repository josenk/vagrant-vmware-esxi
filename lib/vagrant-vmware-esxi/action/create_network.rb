require 'json'
require 'vagrant-vmware-esxi/util/esxcli'

module VagrantPlugins
  module ESXi
    module Action
      # Automatically create network (Port group/VLAN) per subnet
      #
      # For example, when a box given 192.168.1.10/24, create 192.168.1.0/24 port group.
      # Then, when another box is given 192.168.1.20/24, use the same port group from
      # the previous one.
      #
      # Example configuration:
      #   config.vm.network "private_network", ip: "192.168.10.170", netmask: "255.255.255.0",
      #
      # This will create port group '{vSwitchName}-192.168.10.0-24'.
      #
      # You can also use manual configurations for the vSwitch and the port group, such as:
      #   config.vm.network "private_network", ip: "192.168.10.170", netmask: "255.255.255.0",
      #     esxi__vswitch: "Internal Switch", esxi__port_group: "Internal Network"
      #
      # Notes:
      # 1. If you specify only esxi__port_group, a new port group will be created on the default_vswitch if
      # not already created. If you specify only esxi__vswitch, the default_port_group will be used, and
      # it will error if there's a mismatch. In this case, you should probably specify both.
      # 2. If you specify both esxi__port_group and esxi__vswitch, a new port group will be created
      # on that vSwitch if not already created.
      #
      # For (1) and (2), the vSwitch will also be created if not already created. In any case,
      # if esxi__port_group already exists, the esxi__vswitch is ignored (not in the VMX file).
      class CreateNetwork
        include Util::ESXCLI

        CREATE_NETWORK_MUTEX = Mutex.new

        MAX_VLAN = 4094
        VLANS = Array.new(MAX_VLAN) { |i| i + 1 }.freeze

        def initialize(app, env)
          @app = app
          @logger = Log4r::Logger.new('vagrant_vmware_esxi::action::create_network')
        end

        def call(env)
          @env = env
          @default_vswitch = env[:machine].provider_config.default_vswitch
          @default_port_group = env[:machine].provider_config.default_port_group
          create_network
          @app.call(env)
        end

        def create_network
          CREATE_NETWORK_MUTEX.synchronize do
            @env[:ui].info I18n.t("vagrant_vmware_esxi.vagrant_vmware_esxi_message",
                                  message: "Default network on Adapter 1: vSwitch: #{@default_vswitch}, "\
                                  "port group: #{@default_port_group}")
            @env[:ui].info I18n.t("vagrant_vmware_esxi.vagrant_vmware_esxi_message",
                                  message: "Creating other networks...")
            @created_vswitches = []
            @created_port_groups = []

            connect_ssh do
              @env[:machine].config.vm.networks.each.with_index do |(type, network_options), index|
                adapter = index + 2
                next if type != :private_network && type != :public_network
                set_network_configs(adapter, type, network_options)
                create_vswitch_unless_created(network_options)
                create_port_group_unless_created(network_options)

                details = "vSwitch: #{network_options[:esxi__vswitch]}, "\
                  "port group: #{network_options[:esxi__port_group]}"
                @env[:ui].detail I18n.t("vagrant_vmware_esxi.vagrant_vmware_esxi_message",
                                        message: "Adapter #{adapter}: #{details}")
              end
            end

            save_created_networks
          end
        end

        def set_network_configs(adapter, type, network_options)
          # TODO Does this matter? we don't really care where default_vswitch is bridged to anyway
          # Assume public_network is using provider_config default_vswitch and default_port_group
          private_network_configs = [:esxi__vswitch, :esxi__port_group, :dhcp] & network_options.keys
          if type == :public_network && private_network_configs.any?
            raise Errors::ESXiError,
              message: "Setting #{private_network_configs.join(', ')} not allowed for `public_network`."
          end

          custom_vswitch = true if network_options[:esxi__vswitch]
          dhcp = network_options[:type] == "dhcp" || !network_options[:ip]
          network_options[:esxi__vswitch] ||= @default_vswitch
          network_options[:netmask] ||= 24 unless dhcp

          network_options[:esxi__port_group] ||=
            if custom_vswitch || dhcp
              @default_port_group
            else
              # Use the address to generate the port_group name
              ip = IPAddr.new("#{network_options[:ip]}/#{network_options[:netmask]}")
              "#{network_options[:esxi__vswitch]}-#{ip.to_s}-#{ip.prefix}"
            end
        end

        def create_vswitch_unless_created(network_options)
          @logger.info("Creating vSwitch '#{network_options[:esxi__vswitch]}' if not yet created")

          vswitch = network_options[:esxi__vswitch]
          unless has_vswitch? vswitch
            if create_vswitch(vswitch)
              @created_vswitches << vswitch
            else
              raise Errors::ESXiError, message: "Unable create new vSwitch '#{vswitch}'."
            end
          end
        end

        def create_port_group_unless_created(network_options)
          port_groups = get_port_groups
          @logger.debug("Port groups: #{port_groups}")

          if port_group = port_groups[network_options[:esxi__port_group]]
            # port group already created
            unless port_group[:vswitch] == network_options[:esxi__vswitch]
              raise Errors::ESXiError, message: "Existing port group '#{network_options[:esxi__port_group]}' "\
                "must be in vSwitch '#{network_options[:esxi__vswitch]}'"
            end

            return
          end

          # VLAN 0 is bridged to physical NIC by default
          vlan_ids = port_groups.values.map { |v| v[:vlan] }.uniq.sort - [0]
          vlan = (VLANS - vlan_ids).first
          unless vlan
            raise Errors::ESXiError,
              message: "No more VLAN (max: #{MAX_VLAN}) to assign to the port group"
          end

          # TODO check max port groups per vSwitch (512)

          vswitch = network_options[:esxi__vswitch] || @default_vswitch
          @logger.info("Creating port group #{network_options[:esxi__port_group]} on vSwitch '#{vswitch}'")
          unless create_port_group(network_options[:esxi__port_group], vswitch, vlan)
            raise Errors::ESXiError, message: "Cannot create port group "\
              "`#{network_options[:esxi__port_group]}`, VLAN #{vlan}"
          end

          @created_port_groups << network_options[:esxi__port_group]
        end

        # Save networks created by this action
        def save_created_networks
          @logger.debug("Save created networks")
          file = @env[:machine].data_dir.join("networks")

          if file.exist?
            json = JSON.parse(file.read) 
            @logger.debug("Previously saved networks: #{json}")
            json["port_groups"] = json["port_groups"].concat(@created_port_groups.uniq).uniq
            json["vswitches"] = json["vswitches"].concat(@created_vswitches.uniq).uniq
          else
            json = { port_groups: @created_port_groups.uniq, vswitches: @created_vswitches.uniq }
          end

          File.write(file, JSON.generate(json))
        end
      end
    end
  end
end
