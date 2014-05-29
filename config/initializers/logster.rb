if Rails.env.production?
  # honestly, Rails should not be logging this, its real noisy
  Logster.store.ignore = [
    /^ActionController::RoutingError \(No route matches/
  ]

  Logster.config.authorize_callback = lambda{|env|
    user = CurrentUser.lookup_from_env(env)
    user && user.admin
  }
end

# middleware that logs errors sits before multisite
# we need to establish a connection so redis connection is good
# and db connection is good
Logster.config.current_context = lambda{|env,&blk|
  begin
    if Rails.configuration.multisite
      request = Rack::Request.new(env)
      ActiveRecord::Base.connection_handler.clear_active_connections!
      RailsMultisite::ConnectionManagement.establish_connection(:host => request['__ws'] || request.host)
    end
    blk.call
  ensure
    ActiveRecord::Base.connection_handler.clear_active_connections!
  end
}
