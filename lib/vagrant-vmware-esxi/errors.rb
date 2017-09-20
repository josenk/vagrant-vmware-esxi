require 'vagrant'

module VagrantPlugins
  module ESXi
    module Errors
      # Error class
      class VagrantESXiErrors < Vagrant::Errors::VagrantError
        error_namespace('vagrant_vmware_esxi.errors')
      end

      # Error class
      class ESXiError < VagrantESXiErrors
        error_key(:esxi_error)
      end

      # Error class
      class ESXiConfigError < VagrantESXiErrors
        error_key(:esxi_config_error)
      end

      # Error class
      class OVFToolError < VagrantESXiErrors
        error_key(:esxi_ovftool_error)
      end
      # Error class
      class GeneralError < VagrantESXiErrors
        error_key(:general_error)
      end
    end
  end
end
