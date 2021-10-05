#source 'https://rubygems.org'
#
#group :development do
#  #gem 'vagrant', git: 'https://github.com/hashicorp/vagrant.git', :branch => 'v2.2.3'
#  gem 'vagrant', git: 'https://github.com/hashicorp/vagrant.git'
#end
#
#group :plugins do
#  #gemspec
#  gem "vagrant-vmware-esxi", path: "."
#end

source "https://rubygems.org"

group :development do
  # Need to tag to 2.2.4, there is still a bug.
  # https://github.com/hashicorp/vagrant/pull/10945
  #gem "vagrant", git: "https://github.com/hashicorp/vagrant.git", :tag => 'v2.2.4'
  gem "vagrant", git: "https://github.com/hashicorp/vagrant.git", :tag => 'v2.2.10'
end

group :plugins do
  gem "vagrant-vmware-esxi", path: "."
end

