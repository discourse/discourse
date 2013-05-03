load 'deploy' if respond_to?(:namespace)
load 'deploy/assets'
Dir['vendor/plugins/*/recipes/*.rb'].each { |plugin| load(plugin) }
load 'config/deploy'
