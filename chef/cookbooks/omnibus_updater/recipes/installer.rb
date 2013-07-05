include_recipe 'omnibus_updater'
remote_path = node[:omnibus_updater][:full_url].to_s

ruby_block 'Omnibus Chef install notifier' do
  block{ true }
  action :nothing
  subscribes :create, "remote_file[omnibus_remote[#{File.basename(remote_path)}]]", :immediately
  notifies :run, "execute[omnibus_install[#{File.basename(remote_path)}]]", :delayed
end

execute "omnibus_install[#{File.basename(remote_path)}]" do
  case File.extname(remote_path)
  when '.deb'
    command "dpkg -i #{File.join(node[:omnibus_updater][:cache_dir], File.basename(remote_path))}"
  when '.rpm'
    command "rpm -Uvh #{File.join(node[:omnibus_updater][:cache_dir], File.basename(remote_path))}"
  when '.sh'
    command "/bin/sh #{File.join(node[:omnibus_updater][:cache_dir], File.basename(remote_path))}"
  else
    raise "Unknown package type encountered for install: #{File.extname(remote_path)}"
  end
  action :nothing
  notifies :create, 'ruby_block[omnibus chef killer]', :immediately
end

ruby_block 'omnibus chef killer' do
  block do
    raise 'New omnibus chef version installed. Killing Chef run!'
  end
  action :nothing
  only_if do
    node[:omnibus_updater][:kill_chef_on_upgrade]
  end
end

include_recipe 'omnibus_updater::old_package_cleaner'
