include_recipe 'omnibus_updater::set_remote_path'

remote_file "chef omnibus_package[#{File.basename(node[:omnibus_updater][:full_uri])}]" do
  path File.join(node[:omnibus_updater][:cache_dir], File.basename(node[:omnibus_updater][:full_uri]))
  source node[:omnibus_updater][:full_uri]
  backup false
  not_if do
    File.exists?(
      File.join(node[:omnibus_updater][:cache_dir], File.basename(node[:omnibus_updater][:full_uri]))
    ) || (
      Chef::VERSION.to_s.scan(/\d+\.\d+\.\d+/) == node[:omnibus_updater][:full_version].scan(/\d+\.\d+\.\d+/) && OmnibusChecker.is_omnibus?
    )
  end
  notifies :create, 'ruby_block[Omnibus Chef install notifier]', :delayed
end

ruby_block 'Omnibus Chef install notifier' do
  block do
    true
  end
  action :nothing
  notifies :run, "execute[chef omnibus_install[#{node[:omnibus_updater][:full_version]}]]", :delayed
end

execute "chef omnibus_install[#{node[:omnibus_updater][:full_version]}]" do
  command "dpkg -i #{File.join(node[:omnibus_updater][:cache_dir], File.basename(node[:omnibus_updater][:full_uri]))}"
  action :nothing
end

include_recipe 'omnibus_updater::old_package_cleaner'
