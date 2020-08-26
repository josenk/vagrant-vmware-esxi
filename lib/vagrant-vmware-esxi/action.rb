require 'vagrant/action/builder'

module VagrantPlugins
  module ESXi
    # actions and how to run them
    module Action
      include Vagrant::Action::Builtin

      def self.action_read_state
        Vagrant::Action::Builder.new.tap do |b|
          b.use SetESXiPassword
          b.use ReadState
        end
      end

      def self.action_read_ssh_info
        Vagrant::Action::Builder.new.tap do |b|
          b.use SetESXiPassword
          b.use ReadSSHInfo
        end
      end

      def self.action_halt
        Vagrant::Action::Builder.new.tap do |b|
          b.use SetESXiPassword
          b.use Call, ReadState do |env1, b1|
            if env1[:machine_state].to_s == 'running'
              b1.use Shutdown
              b1.use Call, WaitForState, :powered_off, 30 do |env1, b2|
                b2.use Halt unless env1[:result] == 'True'
              end
            else
              b1.use Halt
            end
          end
        end
      end

      def self.action_suspend
        Vagrant::Action::Builder.new.tap do |b|
          b.use SetESXiPassword
          b.use ReadState
          b.use Suspend
        end
      end

      def self.action_resume
        Vagrant::Action::Builder.new.tap do |b|
          b.use SetESXiPassword
          b.use Call, ReadState do |env1, b1|
            if env1[:machine_state].to_s == 'not_created'
              b1.use Resume
            else
              b1.use Resume
              b1.use WaitForState, :running, 240
            end
          end
        end
      end

      def self.action_ssh
        Vagrant::Action::Builder.new.tap do |b|
          b.use SetESXiPassword
          b.use ReadState
          b.use ReadSSHInfo
          b.use SSHExec
        end
      end

      def self.action_ssh_run
        Vagrant::Action::Builder.new.tap do |b|
          b.use SetESXiPassword
          b.use ReadState
          b.use ReadSSHInfo
          b.use SSHRun
        end
      end

      def self.action_snapshot_list
        Vagrant::Action::Builder.new.tap do |b|
          b.use SetESXiPassword
          b.use SnapshotList
        end
      end

      def self.action_address
        Vagrant::Action::Builder.new.tap do |b|
          b.use SetESXiPassword
          b.use Address, false
        end
      end
      def self.action_address_multi
        Vagrant::Action::Builder.new.tap do |b|
          b.use SetESXiPassword
          b.use Address, true
        end
      end

      def self.action_snapshot_info
        Vagrant::Action::Builder.new.tap do |b|
          b.use SetESXiPassword
          b.use SnapshotInfo
        end
      end

      def self.action_snapshot_save
        Vagrant::Action::Builder.new.tap do |b|
          b.use SetESXiPassword
          b.use SnapshotSave
        end
      end

      def self.action_snapshot_restore
        Vagrant::Action::Builder.new.tap do |b|
          b.use SetESXiPassword
          b.use Halt
          b.use Call, WaitForState, :powered_off, 240 do |env1, b1|
            if env1[:result] == 'True'
              b1.use SnapshotRestore
              b1.use ReadState
              b1.use Boot
              b1.use WaitForState, :running, 240
            end
          end
        end
      end

      def self.action_snapshot_delete
        Vagrant::Action::Builder.new.tap do |b|
          b.use SetESXiPassword
          b.use SnapshotDelete
        end
      end


      def self.action_destroy
        Vagrant::Action::Builder.new.tap do |b|
          b.use SetESXiPassword
          b.use Call, ReadState do |env1, b1|
            b1.use Halt unless env1[:machine_state] == 'powered_off'
            b1.use ReadState
            b1.use Destroy
            b1.use DestroyUnusedNetworks
          end
        end
      end

      def self.action_destroy_networks
        Vagrant::Action::Builder.new.tap do |b|
          b.use SetESXiPassword
          b.use Call, DestroyUnusedNetworksConfirm do |env1, b1|
            if env1[:result]
              b1.use DestroyUnusedNetworks
            end
          end
        end
      end

      def self.action_reload
        Vagrant::Action::Builder.new.tap do |b|
          b.use SetESXiPassword
          b.use Call, ReadState do |env1, b1|
            if (env1[:machine_state].to_s == 'powered_on') ||
               (env1[:machine_state].to_s == 'running') ||
               (env1[:machine_state].to_s == 'suspended')
              b1.use action_halt
            end
            b1.use action_up
          end
        end
      end

      def self.action_up
        Vagrant::Action::Builder.new.tap do |b|
          b.use SetESXiPassword
          b.use ConfigValidate
          b.use HandleBox
          b.use ReadState
          b.use CreateNetwork
          b.use CreateVM
          b.use ReadState
          b.use Boot
          b.use Call, WaitForState, :running, 240 do |env1, b1|
            if env1[:result] == 'True'
              b1.use SetNetworkIP
              b1.use action_provision
            end
          end
        end
      end

      def self.action_provision
        Vagrant::Action::Builder.new.tap do |b|
          b.use SetESXiPassword
          b.use ReadState
          b.use Call, WaitForState, :running, 240 do |env1, b1|
            if env1[:result] == 'True'
              b1.use ReadState
              b1.use Provision
              b1.use SyncedFolderCleanup
              b1.use SyncedFolders
              b1.use SetHostname
            end
          end
        end
      end

      def self.action_package
        Vagrant::Action::Builder.new.tap do |b|
          b.use SetESXiPassword
          b.use ReadState
          b.use Package
        end
      end

      action_root = Pathname.new(File.expand_path('../action', __FILE__))
      autoload :SetESXiPassword, action_root.join('esxi_password')
      autoload :CreateVM, action_root.join('createvm')
      autoload :CreateNetwork, action_root.join('create_network')
      autoload :ReadState, action_root.join('read_state')
      autoload :ReadSSHInfo, action_root.join('read_ssh_info')
      autoload :SetNetworkIP, action_root.join('set_network_ip')
      autoload :Boot, action_root.join('boot')
      autoload :Halt, action_root.join('halt')
      autoload :Shutdown, action_root.join('shutdown')
      autoload :Destroy, action_root.join('destroy')
      autoload :DestroyUnusedNetworks, action_root.join('destroy_unused_networks')
      autoload :DestroyUnusedNetworksConfirm, action_root.join('destroy_unused_networks_confirm')
      autoload :Suspend, action_root.join('suspend')
      autoload :Resume, action_root.join('resume')
      autoload :Package, action_root.join('package')
      autoload :SnapshotInfo, action_root.join('snapshot_info')
      autoload :SnapshotList, action_root.join('snapshot_list')
      autoload :SnapshotSave, action_root.join('snapshot_save')
      autoload :SnapshotDelete, action_root.join('snapshot_delete')
      autoload :SnapshotRestore, action_root.join('snapshot_restore')
      autoload :WaitForState, action_root.join('wait_for_state')
      autoload :Address, action_root.join('address')
    end
  end
end
