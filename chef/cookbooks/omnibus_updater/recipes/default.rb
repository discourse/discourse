if node[:omnibus_updater][:disabled]
  Chef::Log.warn 'Omnibus updater disabled via `disabled` attribute'
elsif node[:omnibus_updater][:install_via]
  case node[:omnibus_updater][:install_via]
  when 'deb'
    include_recipe 'omnibus_updater::deb_package'
  when 'rpm'
    include_recipe 'omnibus_updater::rpm_package'
  when 'script'
    include_recipe 'omnibus_updater::script'
  else
    raise "Unknown omnibus update method requested: #{node[:omnibus_updater][:install_via]}"
  end
else
  case node.platform_family
  when 'debian'
    include_recipe 'omnibus_updater::deb_package'
  when 'fedora', 'rhel'
    include_recipe 'omnibus_updater::rpm_package'
  else
    include_recipe 'omnibus_updater::script'
  end
end

include_recipe 'omnibus_updater::remove_chef_system_gem' if node[:omnibus_updater][:remove_chef_system_gem]
