# NOTE: This recipe is here for others that just want the
# package, not the actual installation (lxc for example)

include_recipe 'omnibus_updater::set_remote_path'

remote_file "chef omnibus_package_downloader[#{File.basename(node[:omnibus_updater][:full_uri])}]" do
  path File.join(node[:omnibus_updater][:cache_dir], File.basename(node[:omnibus_updater][:full_uri]))
  source node[:omnibus_updater][:full_uri]
  backup false
  only_if do
    node[:omnibus_updater][:cache_omnibus_installer] &&
    !File.exists?(
      File.join(node[:omnibus_updater][:cache_dir], File.basename(node[:omnibus_updater][:full_uri]))
    )
  end
end

include_recipe 'omnibus_updater::old_package_cleaner'
