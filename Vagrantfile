# -*- mode: ruby -*-
# vi: set ft=ruby :
# See https://github.com/discourse/discourse/blob/master/docs/VAGRANT.md
#
require 'socket'
Vagrant.configure("2") do |config|
  config.vm.box = 'discourse-0.9.7'
  config.vm.box_url = 'http://www.discourse.org/vms/discourse-0.9.7.box'

  # Make this VM reachable on the host network as well, so that other
  # VM's running other browsers can access our dev server.
  config.vm.network :private_network, ip: "192.168.10.200"

  # Make it so that network access from the vagrant guest is able to
  # use SSH private keys that are present on the host without copying
  # them into the VM.
  config.ssh.forward_agent = true

  config.vm.provider :virtualbox do |v|
    # This setting gives the VM 1024MB of RAM instead of the default 384.
    v.customize ["modifyvm", :id, "--memory", [ENV['DISCOURSE_VM_MEM'].to_i, 1024].max]

    # This setting makes it so that network access from inside the vagrant guest
    # is able to resolve DNS using the hosts VPN connection.
    v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
  end

  config.vm.network :forwarded_port, guest: 3000, host: 4000
  config.vm.network :forwarded_port, guest: 1080, host: 4080 # Mailcatcher

  nfs_setting = RUBY_PLATFORM =~ /darwin/ || RUBY_PLATFORM =~ /linux/
  config.vm.synced_folder ".", "/vagrant", id: "vagrant-root", :nfs => nfs_setting

  config.vm.provision :shell, :inline => "apt-get -qq update && apt-get -qq -y install ruby1.9.3 build-essential && gem install chef --no-rdoc --no-ri --conservative"

  host_ip = Socket.ip_address_list.detect{|intf| intf.ipv4_private?}.ip_address
  chef_cookbooks_path = ["chef/cookbooks"]

  # This run uses the updated chef-solo and does normal configuration
  config.vm.provision :chef_solo do |chef|
    chef.binary_env = "GEM_HOME=/opt/chef/embedded/lib/ruby/gems/1.9.1/ GEM_PATH= "
    chef.binary_path = "/opt/chef/bin/"
    chef.cookbooks_path = chef_cookbooks_path

    chef.json = {
        "vagrant_host" => {
            "ip" => host_ip,
            "hostname" => ENV['HOST_HOSTNAME']
        }
    }

    chef.add_recipe "recipe[apt]"
    chef.add_recipe "recipe[build-essential]"
    chef.add_recipe "recipe[vim]"
    chef.add_recipe "recipe[java]"
    chef.add_recipe "discourse"
  end
end
