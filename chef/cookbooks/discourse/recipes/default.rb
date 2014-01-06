# Install the configuration files we need
cookbook_file "/vagrant/config/redis.yml" do
  source "redis.yml"
end