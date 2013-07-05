if(node[:omnibus_updater][:disabled])
  Chef::Log.warn 'Omnibus updater disabled via `disabled` attribute'
else
  include_recipe 'omnibus_updater::downloader'
  include_recipe 'omnibus_updater::installer'
end

if(node[:omnibus_updater][:remove_chef_system_gem])
  include_recipe 'omnibus_updater::remove_chef_system_gem'
end
