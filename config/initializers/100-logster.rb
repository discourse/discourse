# frozen_string_literal: true

if GlobalSetting.skip_redis?
  if Rails.logger.respond_to? :chained
    Rails.logger = Rails.logger.chained.first
  end
  return
end

if Rails.env.development? && RUBY_VERSION.match?(/^2\.5\.[23]/)
  STDERR.puts "WARNING: Discourse development environment runs slower on Ruby 2.5.3 or below"
  STDERR.puts "We recommend you upgrade to Ruby 2.6.1 for the optimal development performance"

  # we have to used to older and slower version of the logger cause the new one exposes a Ruby bug in
  # the Queue class which causes segmentation faults
  Logster::Scheduler.disable
end

if Rails.env.development? && !Sidekiq.server? && ENV["RAILS_LOGS_STDOUT"] == "1"
  console = ActiveSupport::Logger.new(STDOUT)
  original_logger = Rails.logger.chained.first
  console.formatter = original_logger.formatter
  console.level = original_logger.level

  unless ActiveSupport::Logger.logger_outputs_to?(original_logger, STDOUT)
    original_logger.extend(ActiveSupport::Logger.broadcast(console))
  end
end

if Rails.env.production?
  Logster.store.ignore = [
    # honestly, Rails should not be logging this, its real noisy
    /^ActionController::RoutingError \(No route matches/,

    /^PG::Error: ERROR:\s+duplicate key/,

    /^ActionController::UnknownFormat/,
    /^ActionController::UnknownHttpMethod/,
    /^AbstractController::ActionNotFound/,
    # ignore any empty JS errors that contain blanks or zeros for line and column fields
    #
    # Line:
    # Column:
    #
    /(?m).*?Line: (?:\D|0).*?Column: (?:\D|0)/,

    # suppress empty JS errors (covers MSIE 9, etc)
    /^(Syntax|Script) error.*Line: (0|1)\b/m,

    # CSRF errors are not providing enough data
    # suppress unconditionally for now
    /^Can't verify CSRF token authenticity.$/,

    # Yandex bot triggers this JS error a lot
    /^Uncaught ReferenceError: I18n is not defined/,

    # related to browser plugins somehow, we don't care
    /Error calling method on NPObject/,

    # 404s can be dealt with elsewhere
    /^ActiveRecord::RecordNotFound/,

    # bad asset requested, no need to log
    /^ActionController::BadRequest/,

    # we can't do anything about invalid parameters
    /Rack::QueryParser::InvalidParameterError/,

    # we handle this cleanly in the message bus middleware
    # no point logging to logster
    /RateLimiter::LimitExceeded.*/m,

    # see https://github.com/rails/rails/issues/34599
    # Poll defines an enum with the value `open` ActiveRecord then attempts
    # AR then warns cause #open is being redefined, it is already defined
    # privately in Kernel per: http://ruby-doc.org/core-2.5.3/Kernel.html#method-i-open
    # Once the rails issue is fixed we can stop this error suppression and stop defining
    # scopes for the enums
    /^Creating scope :open\. Overwriting existing method Poll\.open\./,
  ]
  Logster.config.env_expandable_keys.push(:hostname, :problem_db)
end

Logster.store.max_backlog = GlobalSetting.max_logster_logs

# middleware that logs errors sits before multisite
# we need to establish a connection so redis connection is good
# and db connection is good
Logster.config.current_context = lambda { |env, &blk|
  begin
    if Rails.configuration.multisite
      request = Rack::Request.new(env)
      ActiveRecord::Base.connection_handler.clear_active_connections!
      RailsMultisite::ConnectionManagement.establish_connection(host: request['__ws'] || request.host)
    end
    blk.call
  ensure
    ActiveRecord::Base.connection_handler.clear_active_connections!
  end
}

# TODO logster should be able to do this automatically
Logster.config.subdirectory = "#{GlobalSetting.relative_url_root}/logs"

Logster.config.application_version = Discourse.git_version
Logster.config.enable_custom_patterns_via_ui = true
Logster.config.enable_js_error_reporting = GlobalSetting.enable_js_error_reporting

store = Logster.store
redis = Logster.store.redis
store.redis_prefix = Proc.new { redis.namespace }
store.redis_raw_connection = redis.without_namespace
severities = [Logger::WARN, Logger::ERROR, Logger::FATAL, Logger::UNKNOWN]

RailsMultisite::ConnectionManagement.each_connection do
  error_rate_per_minute = SiteSetting.alert_admins_if_errors_per_minute rescue 0

  if (error_rate_per_minute || 0) > 0
    store.register_rate_limit_per_minute(severities, error_rate_per_minute) do |rate|
      MessageBus.publish("/logs_error_rate_exceeded",
        {
          rate: rate,
          duration: 'minute',
          publish_at: Time.current.to_i
        },
        group_ids: [Group::AUTO_GROUPS[:admins]]
      )
    end
  end

  error_rate_per_hour = SiteSetting.alert_admins_if_errors_per_hour rescue 0

  if (error_rate_per_hour || 0) > 0
    store.register_rate_limit_per_hour(severities, error_rate_per_hour) do |rate|
      MessageBus.publish("/logs_error_rate_exceeded",
        {
          rate: rate,
          duration: 'hour',
          publish_at: Time.current.to_i,
        },
        group_ids: [Group::AUTO_GROUPS[:admins]]
      )
    end
  end
end

if Rails.configuration.multisite
  if Rails.logger.respond_to? :chained
    chained = Rails.logger.chained
    chained && chained.first.formatter = RailsMultisite::Formatter.new
  end
end

Logster.config.project_directories = [
  { path: Rails.root.to_s, url: "https://github.com/discourse/discourse", main_app: true }
]
Discourse.plugins.each do |plugin|
  next if !plugin.metadata.url

  Logster.config.project_directories << {
    path: "#{Rails.root.to_s}/plugins/#{plugin.directory_name}",
    url: plugin.metadata.url
  }
end
