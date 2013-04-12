if Rails.configuration.respond_to?(:enable_rack_cache) && Rails.configuration.enable_rack_cache
  require 'rack-cache'
  require 'redis-rack-cache'

  url = DiscourseRedis.url

  class Rack::Cache::Discourse < Rack::Cache::Context
    def initialize(app, options={})
      @app = app
      super
    end
    def call(env)
      if CurrentUser.has_auth_cookie?(env)
        @app.call(env)
      else
        super
      end
    end
  end

  Rails.configuration.middleware.insert 0, Rack::Cache::Discourse,
    metastore: "#{url}/metastore",
    entitystore: "#{url}/entitystore",
    verbose: !Rails.env.production?
end
