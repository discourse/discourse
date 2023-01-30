# frozen_string_literal: true

Discourse::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  config.eager_load = true

  # Code is not reloaded between requests
  config.cache_classes = true

  config.log_level = :info

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # in profile mode we serve static assets
  config.public_file_server.enabled = true

  # Compress JavaScripts and CSS
  config.assets.compress = true

  # stuff should be pre-compiled, allow compilation to make life easier
  config.assets.compile = true

  # Generate digests for assets URLs
  config.assets.digest = true

  # Specifies the header that your server uses for sending files
  config.action_dispatch.x_sendfile_header = "X-Accel-Redirect" # for nginx

  # we recommend you use mailhog https://github.com/mailhog/MailHog
  config.action_mailer.smtp_settings = { address: "localhost", port: 1025 }

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify

  # allows users to use mini profiler
  config.load_mini_profiler = false

  # we don't need full logster support, but need to keep it working
  config.after_initialize { Logster.logger = Rails.logger }

  # for profiling with perftools
  # config.middleware.use ::Rack::PerftoolsProfiler, default_printer: 'gif'
end
