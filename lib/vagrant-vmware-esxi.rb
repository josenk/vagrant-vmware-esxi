require 'pathname'
require 'vagrant-vmware-esxi/ext'
require 'vagrant-vmware-esxi/plugin'

module VagrantPlugins
  # Main entry for ESXi vagrant plugin
  module ESXi
    lib_path = Pathname.new(File.expand_path('../vagrant-vmware-esxi', __FILE__))
    autoload :Action, lib_path.join('action')
    autoload :Errors, lib_path.join('errors')

    # This returns the path to the source of this plugin.
    #
    # @return [Pathname]
    def self.source_root
      @source_root ||= Pathname.new(File.expand_path('../../', __FILE__))
    end
  end
end
