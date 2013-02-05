# See https://github.com/discourse/core/blob/master/DEVELOPMENT.md
#
Vagrant::Config.run do |config|
  config.vm.box = 'discourse-pre'
  config.vm.box_url = 'http://www.discourse.org/vms/discourse-pre.box'
  config.vm.network :hostonly, '192.168.10.200'

  config.vm.forward_port 3000, 4000
  config.vm.forward_port 1080, 4080 # Mailcatcher

  if RUBY_PLATFORM =~ /darwin/
    config.vm.share_folder("v-root", "/vagrant", ".", :nfs => true)
  end
end
