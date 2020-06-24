# frozen_string_literal: true

# we want MesageBus to be close to the front
# this is important cause the vast majority of web requests go to it
# this allows us to avoid full middleware crawls each time
#
# We aren't manipulating the middleware stack directly because of
# https://github.com/rails/rails/pull/27936

Rails.configuration.middleware.unshift(MessageBus::Rack::Middleware)

# no reason to track this in development, that is 300+ redis calls saved per
# page view (we serve all assets out of thin in development)
if Rails.env != 'development' || ENV['TRACK_REQUESTS']
  require 'middleware/request_tracker'
  Rails.configuration.middleware.unshift Middleware::RequestTracker

  if GlobalSetting.enable_performance_http_headers
    MethodProfiler.ensure_discourse_instrumentation!
  end
end

if Rails.configuration.multisite
  # Multisite needs to be first, because the request tracker and message bus rely on it
  Rails.configuration.middleware.unshift RailsMultisite::Middleware, RailsMultisite::DiscoursePatches.config
  Rails.configuration.middleware.delete ActionDispatch::Executor

  if defined?(RailsFailover::ActiveRecord) && Rails.configuration.active_record_rails_failover
    Rails.configuration.middleware.insert_after(RailsMultisite::Middleware, RailsFailover::ActiveRecord::Middleware)
  end
elsif defined?(RailsFailover::ActiveRecord) && Rails.configuration.active_record_rails_failover
  Rails.configuration.middleware.insert_before(MessageBus::Rack::Middleware, RailsFailover::ActiveRecord::Middleware)
end
