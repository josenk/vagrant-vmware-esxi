require File.expand_path('../lib/vagrant-vmware-esxi/version', __FILE__)

Gem::Specification.new do |s|
  s.name            = 'vagrant-vmware-esxi'
  s.version         = VagrantPlugins::ESXi::VERSION
  s.date            = '2018-03-21'
  s.summary         = 'Vagrant ESXi provider plugin'
  s.description     = 'A Vagrant plugin that adds a VMware ESXi provider support'
  s.authors         = ['Jonathan Senkerik']
  s.email           = 'josenk@jintegrate.co'
  s.require_paths   = ['lib']
  s.homepage        = 'https://github.com/josenk/vagrant-vmware-esxi'
  s.license         = 'GNU'

  s.files           = `git ls-files`.split($\)
  s.executables     = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files      = s.files.grep(%r{^(test|spec|features)/})

  s.add_runtime_dependency 'i18n', '~> 0.6'
  s.add_runtime_dependency 'log4r', '~> 1.1'
  s.add_runtime_dependency "iniparse", '> 1.0'
  s.add_runtime_dependency "nokogiri", '> 1.5'

  # Needed only to support ed25519 ssh keys with net-ssh 4.x.  Won't need this for net-ssh 5.x.
  #s.add_runtime_dependency 'rbnacl', '>= 4.0', '< 5.0'
  #s.add_runtime_dependency 'rbnacl-libsodium', '= 1.0.16.1'
  #s.add_runtime_dependency 'bcrypt_pbkdf', '>= 1.0'

end
