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

          networks_to_configure = []

          env[:machine].config.vm.networks.each.with_index do |(type, options), index|
            next if type != :private_network && type != :public_network
            next if options[:auto_config] === false

            network = {
              interface: index + 1,
              use_dhcp_assigned_default_route: options[:use_dhcp_assigned_default_route],
              guest_mac_address: options[:mac],
            }

            if options[:ip]
              network.merge!(
                type: :static,
                ip: options[:ip],
                netmask: options[:netmask],
                gateway: options[:gateway]
              )
              ip_msg = "#{options[:ip]}/#{options[:netmask]}"
            else
              network.merge!(type: :dhcp)
              ip_msg = 'dhcp'
            end

            networks_to_configure << network
            env[:ui].info I18n.t('vagrant_vmware_esxi.vagrant_vmware_esxi_message',
                                 message: "Configuring     : #{ip_msg} on #{options[:esxi__port_group]}")
          end

          sleep(1)
          env[:machine].guest.capability(:configure_networks, networks_to_configure)
        end
      end
    end
  end
end
