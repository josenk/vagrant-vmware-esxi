module Ext
  ruby_version = RUBY_VERSION.to_f

  require "vagrant-vmware-esxi/ext/ip_addr" if ruby_version < 2.5
end
