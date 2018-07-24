module VagrantPlugins
  module ESXi

    class SnapshotInfo < Vagrant.plugin(2, :command)
      def self.synopsis
          "Snapshot additional information."
      end
      def execute
        with_target_vms(nil, :provider => "vmware_esxi") do |vm|
          vm.action(:snapshot_info)
        end
      end
    end

    class CapAddress < Vagrant.plugin(2, :command)
      def self.synopsis
          "outputs the IP address of a guest."
      end
      def execute
        with_target_vms(nil, :provider => "vmware_esxi") do |vm|
          vm.action(:address)
        end
      end
    end


  end
end
