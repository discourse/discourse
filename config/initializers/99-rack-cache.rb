if Rails.configuration.respond_to?(:enable_rack_cache) && Rails.configuration.enable_rack_cache
  require 'rack-cache'
  require 'redis-rack-cache'

  url = DiscourseRedis.url

  Rails.configuration.middleware.insert 0, Rack::Cache,
    metastore: "#{url}/metastore",
    entitystore: "#{url}/entitystore",
    verbose: !Rails.env.production?
end
