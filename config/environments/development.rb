# frozen_string_literal: true

Discourse::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # In the development environment your application's code is reloaded on
  # every request.  This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false
  config.file_watcher = ActiveSupport::EventedFileUpdateChecker

  config.eager_load = ENV["DISCOURSE_ZEITWERK_EAGER_LOAD"] == "1"

  # Use the schema_cache.yml file generated during db:migrate (via db:schema:cache:dump)
  config.active_record.use_schema_cache_dump = true

  # Show full error reports and disable caching
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false

  config.action_controller.asset_host = GlobalSetting.cdn_url

  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log

  # Do not compress assets
  config.assets.compress = false

  # Don't Digest assets, makes debugging uglier
  config.assets.digest = false

  config.assets.debug = false

  config.public_file_server.headers = { "Access-Control-Allow-Origin" => "*" }

  # Raise an error on page load if there are pending migrations
  config.active_record.migration_error = :page_load
  config.watchable_dirs["lib"] = [:rb]

  # we recommend you use mailhog https://github.com/mailhog/MailHog
  config.action_mailer.smtp_settings = { address: "localhost", port: 1025 }

  config.action_mailer.raise_delivery_errors = true

  config.log_level = ENV["DISCOURSE_DEV_LOG_LEVEL"] if ENV["DISCOURSE_DEV_LOG_LEVEL"]

  config.active_record.logger = nil if ENV["RAILS_DISABLE_ACTIVERECORD_LOGS"] == "1" ||
    ENV["ENABLE_LOGSTASH_LOGGER"] == "1"
  config.active_record.verbose_query_logs = true if ENV["RAILS_VERBOSE_QUERY_LOGS"] == "1"

  if defined?(BetterErrors)
    BetterErrors::Middleware.allow_ip! ENV["TRUSTED_IP"] if ENV["TRUSTED_IP"]

    if defined?(Unicorn) && ENV["UNICORN_WORKERS"].to_i != 1
      # BetterErrors doesn't work with multiple unicorn workers. Disable it to avoid confusion
      Rails.configuration.middleware.delete BetterErrors::Middleware
    end
  end

  config.load_mini_profiler = true if !ENV["DISABLE_MINI_PROFILER"]

  if hosts = ENV["DISCOURSE_DEV_HOSTS"]
    Discourse.deprecate("DISCOURSE_DEV_HOSTS is deprecated. Use RAILS_DEVELOPMENT_HOSTS instead.")
    config.hosts.concat(hosts.split(","))
  end

  require "middleware/missing_avatars"
  config.middleware.insert 1, Middleware::MissingAvatars

  config.enable_anon_caching = false
  require "rbtrace" if RUBY_ENGINE == "ruby"

  if emails = GlobalSetting.developer_emails
    config.developer_emails = emails.split(",").map(&:downcase).map(&:strip)
  end

  if ENV["DISCOURSE_SKIP_CSS_WATCHER"] != "1" &&
       (defined?(Rails::Server) || defined?(Puma) || defined?(Unicorn))
    require "stylesheet/watcher"
    STDERR.puts "Starting CSS change watcher"
    @watcher = Stylesheet::Watcher.watch
  end

  config.after_initialize do
    config.colorize_logging = true if ENV["RAILS_COLORIZE_LOGGING"] == "1"

    if ENV["RAILS_VERBOSE_QUERY_LOGS"] == "1"
      ActiveRecord::LogSubscriber.backtrace_cleaner.add_silencer do |line|
        line =~ %r{lib/freedom_patches}
      end
    end

    if ENV["BULLET"]
      Bullet.enable = true
      Bullet.rails_logger = true
    end
  end

  config.hosts << /\A(([a-z0-9-]+)\.)*localhost(\:\d+)?\Z/

  config.generators.after_generate do |files|
    parsable_files = files.filter { |file| file.end_with?(".rb") }
    unless parsable_files.empty?
      system("bundle exec rubocop -A --fail-level=E #{parsable_files.shelljoin}", exception: true)
    end
  end
end
