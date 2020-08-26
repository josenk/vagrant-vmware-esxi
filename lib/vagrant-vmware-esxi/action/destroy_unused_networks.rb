require 'vagrant-vmware-esxi/util/esxcli'

module VagrantPlugins
  module ESXi
    module Action
      class DestroyUnusedNetworks
        include Util::ESXCLI

        IP_RE = '(\d{1,3}\.){3}\d{1,3}'
        IP_PREFIX_RE = '\d{1,2}'

        def initialize(app, env)
          @app = app
          @scope = env[:scope]
          @logger = Log4r::Logger.new('vagrant_vmware_esxi::action::destroy_unused_networks')
        end

        def call(env)
          @env = env
          @vmid = env[:machine].id
          connect_ssh { destroy_networks }
          @app.call(env)
        end

        def destroy_networks
          if @scope == :all
            # Destroy ALL unused auto port groups, including the ones created by another `vagrant up`,
            # which match pattern such as:
            #   vSwitch0-192.168.100.0-24 ({vswitch}-{net-address}-{prefix})
            # This WON'T destroy any vSwitches 
            destroy_unused_auto_port_groups
          else
            # Destroy unused port groups that were created by this `vagrant up` 
            destroy_unused_port_groups if @env[:machine].provider_config.destroy_unused_port_groups
            destroy_unused_vswitches if @env[:machine].provider_config.destroy_unused_vswitches
          end
        end

        def destroy_unused_auto_port_groups
          vswitch = @env[:machine].provider_config.default_vswitch
          @env[:ui].info I18n.t("vagrant_vmware_esxi.vagrant_vmware_esxi_message",
                                message: "Destroying unused auto port groups on vswitch '#{vswitch}'...")

          active_port_groups = get_active_port_group_names
          @logger.debug("active port groups: #{active_port_groups}")
          get_port_groups.each do |name, port_group|
            if auto_port_group_re.match?(name) && !active_port_groups.include?(name)
              destroy_unused_port_group(name, port_group[:vswitch])
            end
          end
        end

        def destroy_unused_port_groups
          @env[:ui].info I18n.t("vagrant_vmware_esxi.vagrant_vmware_esxi_message",
                                message: "Destroying unused port groups that were created automatically...")

          all_port_groups = get_port_groups
          active_port_groups = get_active_port_group_names
          @logger.debug("all port groups: #{all_port_groups.inspect}")
          @logger.debug("active port groups: #{active_port_groups}")
          created_networks["port_groups"].each do |port_group|
            found = all_port_groups[port_group]
            unless active_port_groups.include? port_group
              destroy_unused_port_group(port_group, found[:vswitch])
            end
          end
        end

        def destroy_unused_port_group(port_group, vswitch)
          @env[:ui].detail I18n.t("vagrant_vmware_esxi.vagrant_vmware_esxi_message",
                                message: "Destroying port group '#{port_group}'")
          unless remove_port_group(port_group, vswitch)
            raise Errors::ESXiError, message: "Unable to remove port group '#{port_group}'"
          end
        end

        def destroy_unused_vswitches
          @env[:ui].info I18n.t("vagrant_vmware_esxi.vagrant_vmware_esxi_message",
                                message: "Destroying unused vSwitches that were created automatically...")

          @logger.debug("all port groups: #{created_networks["vswitches"].inspect}")
          created_networks["vswitches"].each do |vswitch|
            if get_vswitch_port_group_names(vswitch).empty?
              destroy_unused_vswitch(vswitch)
            end
          end
        end

        def destroy_unused_vswitch(vswitch)
          @env[:ui].detail I18n.t("vagrant_vmware_esxi.vagrant_vmware_esxi_message",
                                  message: "Destroying vswitch '#{vswitch}'")
          unless remove_vswitch(vswitch)
            raise Errors::ESXiError, message: "Unable to remove vswitch '#{vswitch}'"
          end
        end

        def created_networks
          @created_networks ||= (
            file = @env[:machine].data_dir.join("networks")
            if file.exist?
              JSON.parse(File.read(file))
            else
              { "port_groups" => [], "vswitches" => [] }
            end
          )
        end

        def auto_port_group_re
          vswitch = Regexp.escape(@env[:machine].provider_config.default_vswitch)

          @auto_port_group_re ||= /^#{vswitch}-#{IP_RE}-#{IP_PREFIX_RE}$/
        end
      end
    end
  end
end
