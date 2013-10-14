if Rails.configuration.respond_to?(:enable_rack_cache) && Rails.configuration.enable_rack_cache
  require 'rack-cache'
  require 'redis-rack-cache'

  # by default we will cache up to 3 minutes in redis, if you want to cut down on redis usage
  #  cut down this number
  RedisRackCache.max_cache_seconds = 60 * 3

  url = DiscourseRedis.url

  class Rack::Cache::Discourse < Rack::Cache::Context
    def initialize(app, options={})
      @app = app
      super
    end

    def call(env)
      status, headers, body = if CurrentUser.has_auth_cookie?(env)
        @app.call(env)
      else
        super
      end

      cache_control = Rack::Cache::CacheControl.new(headers['Cache-Control'])
      cache_control.merge!('public' => false, 'private' => true)
      headers['Cache-Control'] = cache_control.to_s

      [status, headers, body]
    end
  end

  Rails.configuration.middleware.insert 0, Rack::Cache::Discourse,
    metastore: "#{url}/metastore",
    entitystore: "#{url}/entitystore",
    verbose: !Rails.env.production?
end
