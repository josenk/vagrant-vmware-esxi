require 'log4r'
require 'vagrant/util/network_ip'
require "vagrant/util/scoped_hash_override"

module VagrantPlugins
  module ESXi
    module Action
      # This action set the IP address  (do the config.vm_network settings...)
      class SetNetworkIP
        include Vagrant::Util::NetworkIP
        include Vagrant::Util::ScopedHashOverride

        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new('vagrant_vmware_esxi::action::set_network_ip')
        end

        def call(env)
          set_network_ip(env)
          @app.call(env)
        end

        def set_network_ip(env)
          @logger.info('vagrant-vmware-esxi, set_network_ip: start...')

          # Get config.
          @env = env
          machine = env[:machine]
          config = env[:machine].provider_config

          #  Number of nics configured
          if config.esxi_virtual_network.is_a? Array
            number_of_adapters = config.esxi_virtual_network.count
          else
            number_of_adapters = 1
          end

          #
          #  Make an array of vm.network settings (from Vagrantfile).
          #  One index for each network interface. I'll use private_network and
          #  public_network as both valid.   Since it would be a TERRIBLE idea
          #  to modify ESXi virtual network configurations, I'll just set the IP
          #  using static or DHCP.   Everything else will be ignored...
          #
          vm_network = []
          env[:machine].config.vm.networks.each do |type, options|
            # I only handle private and public networks
            next if type != :private_network && type != :public_network
            next if vm_network.count >= number_of_adapters
            vm_network << options
          end


          if (config.debug =~ %r{true}i)
            puts "num adapters: #{number_of_adapters},  vm.network.count: #{vm_network.count}"
          end

          networks_to_configure = []
          if (number_of_adapters > 1) and (vm_network.count > 0)
            1.upto(number_of_adapters - 1) do |index|
              if !vm_network[index - 1].nil?
                options = vm_network[index - 1]
                next if options[:auto_config] === false
                if options[:ip]
                  ip_class = options[:ip].gsub(/\..*$/,'').to_i
                  if ip_class < 127
                    class_netmask = '255.0.0.0'
                  elsif ip_class > 127 and ip_class < 192
                    class_netmask = '255.255.0.0'
                  elsif ip_class >= 192 and ip_class <= 223
                    class_netmask = '255.255.255.0'
                  end

                  # if netmask is not specified or is invalid, use, class defaults
                  unless options[:netmask]
                     netmask = class_netmask
                  else
                    netmask = options[:netmask]
                  end
                  unless netmask =~ /^(((128|192|224|240|248|252|254)\.0\.0\.0)|(255\.(0|128|192|224|240|248|252|254)\.0\.0)|(255\.255\.(0|128|192|224|240|248|252|254)\.0)|(255\.255\.255\.(0|128|192|224|240|248|252|254)))$/i
                    env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                         message: "WARNING         : Invalid netmask specified, using Class mask (#{class_netmask})")
                    netmask = class_netmask
                  end
                  network = {
                    interface: index,
                    type: :static,
                    use_dhcp_assigned_default_route: options[:use_dhcp_assigned_default_route],
                    guest_mac_address: options[:mac],
                    ip: options[:ip],
                    netmask: netmask,
                    gateway: options[:gateway]
                  }
                  ip_msg = options[:ip] + '/'
                else
                  network = {
                    interface: index,
                    type: :dhcp,
                    use_dhcp_assigned_default_route: options[:use_dhcp_assigned_default_route],
                    guest_mac_address: options[:mac]
                  }
                  ip_msg = 'dhcp'
                  netmask = ''
                end
                networks_to_configure << network
                env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                     message: "Configuring     : #{ip_msg}#{netmask} on #{config.esxi_virtual_network[index]}")
              end
            end

            #
            #  Save network configuration for provisioner to do changes.
            #
            sleep(1)
            env[:machine].guest.capability(
                :configure_networks, networks_to_configure)
          end
        end
      end
    end
  end
end
