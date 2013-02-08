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

  # This setting gives the VM 1024MB of MEMORIES instead of the default 384.
  config.vm.customize ["modifyvm", :id, "--memory", 1024]

  # This setting makes it so that network access from inside the vagrant guest
  # is able to resolve DNS using the hosts VPN connection.
  config.vm.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]

  config.vm.forward_port 3000, 4000
  config.vm.forward_port 1080, 4080 # Mailcatcher

  nfs_setting = RUBY_PLATFORM =~ /darwin/ ? true : false
  config.vm.share_folder("v-root", "/vagrant", ".", :nfs => nfs_setting)
end
