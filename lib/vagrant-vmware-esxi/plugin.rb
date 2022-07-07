#  Plugins
module VagrantPlugins
  module ESXi
    # Class Plugin
    class Plugin < Vagrant.plugin('2')
      name 'vmware-esxi'
      description 'Vagrant VMware-ESXi provider plugin'
      config(:vmware_esxi, :provider) do
        require_relative 'config'
        Config
      end

      provider(
        :vmware_esxi,
        box_format: %w(vmware_esxi vmware vmware_desktop vmware_fusion vmware_workstation),
        parallel: true
      ) do
        setup_logging
        setup_i18n

      require_relative 'provider'
        Provider
      end

      #  Prints the IP address of the guest
      command('address') do
        require_relative 'command'
        CapAddress
      end

      provider_capability('vmware_esxi', 'snapshot_list') do
        require_relative 'cap/snapshot_list'
        Cap::SnapshotList
      end

      command('snapshot-info') do
        require_relative "command"
        SnapshotInfo
      end

      command('destroy-networks') do
        require_relative "command/destroy_networks"
        Command::DestroyNetworks
      end

      # This initializes the internationalization strings.
      def self.setup_i18n
        require 'pathname'
        I18n.load_path << File.expand_path('locales/en.yml', ESXi.source_root)
        I18n.reload!
      end

      # This sets up our log level to be whatever VAGRANT_LOG is.
      def self.setup_logging
        require 'log4r'
        level = nil
        begin
          level = Log4r.const_get(ENV['VAGRANT_LOG'].upcase)
        rescue NameError
          # This means that the logging constant wasn't found,
          # which is fine. We just keep `level` as `nil`. But
          # we tell the user.
          level = nil
        end

        # Some constants, such as "true" resolve to booleans, so the
        # above error checking doesn't catch it. This will check to make
        # sure that the log level is an integer, as Log4r requires.
        level = nil unless level.is_a?(Integer)

        # Set the logging level on all "vagrant" namespaced
        # logs as long as we have a valid level.
        if level
          logger = Log4r::Logger.new('vagrant_vmware_esxi')
          logger.outputters = Log4r::Outputter.stderr
          logger.level = level
          logger = nil
        end
      end
    end
  end
end
