require "optparse"

module VagrantPlugins
  module ESXi
    module Command
      class DestroyNetworks < Vagrant.plugin("2", :command)
        def self.synopsis
          "destroy VMWare ESXi networks (port groups) and vSwitches that were created automatically"
        end

        def execute
          force = false

          opts = OptionParser.new do |o|
            o.banner = "Usage: vagrant destroy-networks"
            o.separator ""
            o.separator "Options:"
            o.separator ""

            o.on("-f", "--force", "Destroy without confirmation.") do |f|
              force = f
            end
          end

          # Parse the options
          argv = parse_options(opts)
          return if !argv

          with_target_vms(nil) do |machine|
            machine.action(:destroy_networks, scope: :all, force_confirm_destroy_networks: force)
          end

          0
        end
      end
    end
  end
end
