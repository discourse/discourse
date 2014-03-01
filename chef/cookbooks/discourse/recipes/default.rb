# Install the configuration files we need
cookbook_file "/vagrant/config/database.yml" do
  source "database.yml"
end

cookbook_file "/vagrant/config/redis.yml" do
  source "redis.yml"
end

hostsfile_entry 'main site' do
  ip_address node['vagrant_host']['ip']
  hostname node['vagrant_host']['hostname']
  action :create_if_missing
end

