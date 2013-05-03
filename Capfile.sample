# For help deploying via Capistrano, see this thread:
# http://meta.discourse.org/t/deploy-discourse-to-an-ubuntu-vps-using-capistrano/6353

load 'deploy' if respond_to?(:namespace)
load 'deploy/assets'
Dir['vendor/plugins/*/recipes/*.rb'].each { |plugin| load(plugin) }
load 'config/deploy'
