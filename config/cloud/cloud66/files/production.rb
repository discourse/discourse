Discourse::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # Code is not reloaded between requests
  config.cache_classes = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Disable Rails's static asset server (Apache or nginx will already do this)
  config.serve_static_assets = false

  # Compress JavaScripts and CSS
  config.assets.compress = true

  # stuff should be pre-compiled
  config.assets.compile = false

  # Generate digests for assets URLs
  config.assets.digest = true

  # Specifies the header that your server uses for sending files
  config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for nginx

  # you may use other configuration here for mail eg: sendgrid

  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
     address: ENV['SMTP_ADDRESS'],
     port: ENV['SMTP_PORT'],
     domain: ENV['SMTP_DOMAIN'],
     user_name: ENV['SMTP_USERNAME'],
     password: ENV['SMTP_PASSWORD'],
     authentication: 'plain',
     enable_starttls_auto: true  }

  #config.action_mailer.delivery_method = :sendmail
  #config.action_mailer.sendmail_settings = {arguments: '-i'}

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify

  # this will cause all handlebars templates to be pre-compiles, making your page faster
  config.handlebars.precompile = true

  # this setting enables rack_cache so it caches various requests in redis
  config.enable_rack_cache = true

  # allows developers to use mini profiler
  config.load_mini_profiler = true

  # allows Cross-origin resource sharing (CORS) for API access in JavaScript (default to false for security).
  # See the initializer and https://github.com/cyu/rack-cors for configuration documentation.
  #
  # config.enable_rack_cors = false
  # config.rack_cors_origins = ['*']
  # config.rack_cors_resource = ['*', { :headers => :any, :methods => [:get, :post, :options] }]

  # Discourse strongly recommend you use a CDN.
  # For origin pull cdns all you need to do is register an account and configure
  # config.action_controller.asset_host = "http://YOUR_CDN_HERE"

end
