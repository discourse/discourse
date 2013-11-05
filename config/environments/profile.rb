Discourse::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  config.eager_load = true if rails4?

  # Code is not reloaded between requests
  config.cache_classes = true

  config.log_level = :info

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # in profile mode we serve static assets
  config.serve_static_assets = true

  # Compress JavaScripts and CSS
  config.assets.compress = true

  # stuff should be pre-compiled, allow compilation to make life easier
  config.assets.compile = true

  # Generate digests for assets URLs
  config.assets.digest = true

  # Specifies the header that your server uses for sending files
  config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for nginx

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = true

  # we recommend you use mailcatcher https://github.com/sj26/mailcatcher
  config.action_mailer.smtp_settings = { address: "localhost", port: 1025 }

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify

  # precompile handlebar assets
  config.handlebars.precompile = true

  # allows users to use mini profiler
  config.enable_mini_profiler = false

  # for profiling with perftools
  # config.middleware.use ::Rack::PerftoolsProfiler, default_printer: 'gif'
end
