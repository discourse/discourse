# frozen_string_literal: true

# we want MessageBus to be close to the front
# this is important cause the vast majority of web requests go to it
# this allows us to avoid full middleware crawls each time
#
# We aren't manipulating the middleware stack directly because of
# https://github.com/rails/rails/pull/27936

require "middleware/processing_request"
Rails.configuration.middleware.unshift(Middleware::ProcessingRequest)
Rails.configuration.middleware.unshift(MessageBus::Rack::Middleware)

# no reason to track this in development, that is 300+ redis calls saved per
# page view (we serve all assets out of thin in development)
if Rails.env != "development" || ENV["TRACK_REQUESTS"]
  require "middleware/request_tracker"
  Rails.configuration.middleware.unshift(Middleware::RequestTracker)
  Rails.configuration.middleware.move_before(Middleware::RequestTracker, ActionDispatch::RemoteIp)

  MethodProfiler.ensure_discourse_instrumentation! if GlobalSetting.enable_performance_http_headers
end

if Rails.env.test?
  # In test mode we can't insert/remove middlewares
  # Therefore we insert a small helper which effectively switches the multisite
  # middleware on/off based on the Rails.configuration.multisite value
  class TestMultisiteMiddleware < RailsMultisite::Middleware
    def call(env)
      return @app.call(env) if !Rails.configuration.multisite
      super(env)
    end
  end

  Rails.configuration.middleware.unshift TestMultisiteMiddleware,
                                         RailsMultisite::DiscoursePatches.config

  class BlockRequestsMiddleware
    RSPEC_CURRENT_EXAMPLE_COOKIE_STRING = "rspec_current_example_location"

    cattr_accessor :current_example_location

    @@block_requests = false

    def self.block_requests!
      @@block_requests = true
    end

    def self.allow_requests!
      @@block_requests = false
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      request = Rack::Request.new(env)

      if (
           @@block_requests ||
             (
               request.xhr? && self.class.current_example_location.present? &&
                 self.class.current_example_location !=
                   request.cookies[RSPEC_CURRENT_EXAMPLE_COOKIE_STRING]
             )
         )
        return [
          503,
          { "Content-Type" => "text/plain" },
          [
            "Blocked by BlockRequestsMiddleware for requests initiated by #{request.cookies[RSPEC_CURRENT_EXAMPLE_COOKIE_STRING]} when running #{self.class.current_example_location}",
          ]
        ]
      end

      status, headers, body = @app.call(env)
      if headers["Content-Type"]&.match?(/html/) && BlockRequestsMiddleware.current_example_location
        headers["Set-Cookie"] = [
          headers["Set-Cookie"],
          "#{RSPEC_CURRENT_EXAMPLE_COOKIE_STRING}=#{BlockRequestsMiddleware.current_example_location}; path=/;",
        ].compact.join("\n")
      end
      [status, headers, body]
    end
  end

  Rails.configuration.middleware.unshift BlockRequestsMiddleware
elsif Rails.configuration.multisite
  assets_hostnames = GlobalSetting.cdn_hostnames

  if assets_hostnames.empty?
    assets_hostnames = Discourse::Application.config.database_configuration[Rails.env]["host_names"]
  end

  RailsMultisite::ConnectionManagement.asset_hostnames = assets_hostnames

  # Multisite needs to be first, because the request tracker and message bus rely on it
  Rails.configuration.middleware.unshift RailsMultisite::Middleware,
                                         RailsMultisite::DiscoursePatches.config
  Rails.configuration.middleware.delete ActionDispatch::Executor

  if defined?(RailsFailover::ActiveRecord) && Rails.configuration.active_record_rails_failover
    Rails.configuration.middleware.insert_after(
      RailsMultisite::Middleware,
      RailsFailover::ActiveRecord::Middleware,
    )
  end

  if Rails.env.development?
    # Automatically allow development multisite hosts
    RailsMultisite::ConnectionManagement.instance.db_spec_cache.each do |db, specification|
      next if db == "default"
      Rails.configuration.hosts.concat(specification.spec.configuration_hash[:host_names])
    end
  end
elsif defined?(RailsFailover::ActiveRecord) && Rails.configuration.active_record_rails_failover
  Rails.configuration.middleware.insert_before(
    MessageBus::Rack::Middleware,
    RailsFailover::ActiveRecord::Middleware,
  )
end
