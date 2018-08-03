require 'optparse'

module VagrantPlugins
  module ESXi

    class SnapshotInfo < Vagrant.plugin(2, :command)
      def self.synopsis
          "Snapshot additional information."
      end
      def execute
        opts = OptionParser.new do |o|
          o.banner = "Usage: vagrant snapshot-info [name]"
        end

        argv = parse_options(opts)

        with_target_vms(argv) do |machine|
          machine.action(:snapshot_info)
        end
      end
    end

    class CapAddress < Vagrant.plugin(2, :command)
      def self.synopsis
          "outputs the IP address of a guest."
      end
      def execute
        opts = OptionParser.new do |o|
          o.banner = "Usage: vagrant address [name]"
        end

        argv = parse_options(opts)

        # Count total number of vms to print the IP
        totalvms = 0
        with_target_vms(argv) do
          totalvms += 1
        end

        if argv.length == 1 or totalvms == 1
          with_target_vms(argv, {:single_target=>true}) do |machine|
            machine.action(:address)
          end
        else
          with_target_vms(argv) do |machine|
            machine.action(:address_multi)
          end
        end
      end
    end

  end
end
