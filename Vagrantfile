# -*- mode: ruby -*-
# vi: set ft=ruby :
# See https://github.com/discourse/core/blob/master/DEVELOPMENT.md
#
Vagrant::Config.run do |config|
  config.vm.box = 'discourse-pre'
  config.vm.box_url = 'http://www.discourse.org/vms/discourse-pre.box'

  # Make this VM reachable on the host network as well, so that other
  # VM's running other browsers can access our dev server.
  config.vm.network :hostonly, '192.168.10.200'

  # Make it so that network access from the vagrant guest is able to
  # use SSH private keys that are present on the host without copying
  # them into the VM.
  config.ssh.forward_agent = true

  # This setting gives the VM 512MB of MEMORIES instead of the default 384.
  config.vm.customize ["modifyvm", :id, "--memory", 512]

  # This setting makes it so that network access from inside the vagrant guest
  # is able to resolve DNS using the hosts VPN connection.
  config.vm.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]

  config.vm.forward_port 3000, 4000
  config.vm.forward_port 1080, 4080 # Mailcatcher

  config.vm.share_folder("v-root", "/vagrant", ".")

  chef_cookbooks_path = ["chef/cookbooks"]

  # The first chef run just upgrades the chef installation using omnibus
  config.vm.provision :chef_solo do |chef|
    chef.binary_env = "GEM_HOME=/opt/vagrant_ruby/lib/ruby/gems/1.8/ GEM_PATH= "
    chef.binary_path = "/opt/vagrant_ruby/bin/"
    chef.cookbooks_path = chef_cookbooks_path
    chef.add_recipe "recipe[omnibus_updater]"
    chef.json = { :omnibus_updater => { 'version_search' => false }}
  end

  # The second chef run uses the updated chef-solo and does normal configuration
  config.vm.provision :chef_solo do |chef|
    chef.binary_env = "GEM_HOME=/opt/chef/embedded/lib/ruby/gems/1.9.1/ GEM_PATH= "
    chef.binary_path = "/opt/chef/bin/"
    chef.cookbooks_path = chef_cookbooks_path
    chef.add_recipe "recipe[apt]"
    chef.add_recipe "recipe[build-essential]"
    chef.add_recipe "recipe[phantomjs]"
    chef.add_recipe "recipe[vim]"
  end
end
