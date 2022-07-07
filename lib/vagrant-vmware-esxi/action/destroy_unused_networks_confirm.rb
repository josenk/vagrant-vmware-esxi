require "vagrant/action/builtin/confirm"

module VagrantPlugins
  module ESXi
    module Action
      class DestroyUnusedNetworksConfirm < Confirm
        def initialize(app, env)
          force_key = :force_confirm_destroy_networks
          # message   = I18n.t("vagrant.commands.destroy.confirmation",
                             # name: env[:machine].name)
          message = "Destroy all networks? "

          super(app, env, message, force_key, allowed: ["y", "n", "Y", "N"])
        end
      end
    end
  end
end
