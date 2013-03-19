# -*- mode: ruby -*-
# vi: set ft=ruby :
# See https://github.com/discourse/discourse/blob/master/docs/VAGRANT.md
#
Vagrant.configure("2") do |config|
  config.vm.box = 'discourse-0.8.4'
  config.vm.box_url = 'http://www.discourse.org/vms/discourse-0.8.4.box'

  # Make this VM reachable on the host network as well, so that other
  # VM's running other browsers can access our dev server.
  config.vm.network :private_network, ip: "192.168.10.200"

  # Make it so that network access from the vagrant guest is able to
  # use SSH private keys that are present on the host without copying
  # them into the VM.
  config.ssh.forward_agent = true

  config.vm.provider :virtualbox do |v|
    # This setting gives the VM 1024MB of MEMORIES instead of the default 384.
    v.customize ["modifyvm", :id, "--memory", 1024]

    # This setting makes it so that network access from inside the vagrant guest
    # is able to resolve DNS using the hosts VPN connection.
    v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
  end

  config.vm.network :forwarded_port, guest: 3000, host: 4000
  config.vm.network :forwarded_port, guest: 1080, host: 4080 # Mailcatcher

  nfs_setting = RUBY_PLATFORM =~ /darwin/ || RUBY_PLATFORM =~ /linux/
  config.vm.synced_folder ".", "/vagrant", :nfs => nfs_setting

  chef_cookbooks_path = ["chef/cookbooks"]

  # The first chef run just upgrades the chef installation using omnibus
  config.vm.provision :chef_solo do |chef|
    chef.binary_env = "GEM_HOME=/opt/vagrant_ruby/lib/ruby/gems/1.8/ GEM_PATH= "
    chef.binary_path = "/opt/vagrant_ruby/bin/"
    chef.cookbooks_path = chef_cookbooks_path
    chef.add_recipe "recipe[omnibus_updater]"
    chef.add_recipe "discourse"
    chef.json = { :omnibus_updater => { 'version_search' => false }}
  end

  # The second chef run uses the updated chef-solo and does normal configuration
  config.vm.provision :chef_solo do |chef|
    chef.binary_env = "GEM_HOME=/opt/chef/embedded/lib/ruby/gems/1.9.1/ GEM_PATH= "
    chef.binary_path = "/opt/chef/bin/"
    chef.cookbooks_path = chef_cookbooks_path
    chef.add_recipe "recipe[apt]"
    chef.add_recipe "recipe[build-essential]"
    chef.add_recipe "recipe[vim]"
  end
end
