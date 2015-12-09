# we want MesageBus in the absolute front
# this is important cause the vast majority of web requests go to it
# this allows us to avoid full middleware crawls each time
Rails.configuration.middleware.delete MessageBus::Rack::Middleware
Rails.configuration.middleware.unshift MessageBus::Rack::Middleware

# no reason to track this in development, that is 300+ redis calls saved per
# page view (we serve all assets out of thin in development)
if Rails.env != 'development' || ENV['TRACK_REQUESTS']
  require 'middleware/request_tracker'
  Rails.configuration.middleware.unshift Middleware::RequestTracker
end

