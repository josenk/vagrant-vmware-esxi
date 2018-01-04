require 'log4r'
require 'vagrant'

module VagrantPlugins
  module ESXi
    # Provider class
    class Provider < Vagrant.plugin('2', :provider)
      def initialize(machine)
        @machine = machine
        @logger = Log4r::Logger.new('vagrant_vmware_esxi::action::provider')
      end

      def action(name)
        method = "action_#{name}"
        if Action.respond_to? method
          Action.send(method)
        else
          # the specified action is not supported
          nil
        end
      end

      def state
        env = @machine.action('read_state')
        state_id = env[:machine_state]

        # Get the short and long description
        @logger.info("vagrant-vmware-esxi, boot: state_id: #{env[:state_id]}")

        short = I18n.t("vagrant_vmware_esxi.states.#{state_id}.short")
        long  = I18n.t("vagrant_vmware_esxi.states.#{state_id}.long")

        # If we're not created, then specify the special ID flag
        if state_id == :not_created
          state_id = Vagrant::MachineState::NOT_CREATED_ID
        end

        # Return the MachineState object
        Vagrant::MachineState.new(state_id, short, long)
      end

      def ssh_info
        env = @machine.action('read_ssh_info')
        env[:machine_ssh_info]
      end
    end
  end
end
