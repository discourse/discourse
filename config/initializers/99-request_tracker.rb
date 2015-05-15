# no reason to track this in development, that is 300+ redis calls saved per
# page view (we serve all assets out of thin in development)
if Rails.env != 'development' || ENV['TRACK_REQUESTS']
  require 'middleware/request_tracker'
  Rails.configuration.middleware.unshift Middleware::RequestTracker
end
