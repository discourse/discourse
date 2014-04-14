# Install the configuration files we need
hostsfile_entry 'main site' do
  ip_address node['vagrant_host']['ip']
  hostname node['vagrant_host']['hostname']
  action :create_if_missing
end

