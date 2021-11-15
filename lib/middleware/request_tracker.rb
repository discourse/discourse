# frozen_string_literal: true

require 'method_profiler'
require 'middleware/anonymous_cache'

class Middleware::RequestTracker
  @@detailed_request_loggers = nil
  @@ip_skipper = nil

  # You can add exceptions to our app rate limiter in the app.yml ENV section.
  # example:
  #
  # env:
  #   DISCOURSE_MAX_REQS_PER_IP_EXCEPTIONS: >-
  #     14.15.16.32/27
  #     216.148.1.2
  #
  STATIC_IP_SKIPPER = ENV['DISCOURSE_MAX_REQS_PER_IP_EXCEPTIONS']&.split&.map { |ip| IPAddr.new(ip) }

  # register callbacks for detailed request loggers called on every request
  # example:
  #
  # Middleware::RequestTracker.detailed_request_logger(->|env, data| do
  #   # do stuff with env and data
  # end
  def self.register_detailed_request_logger(callback)
    MethodProfiler.ensure_discourse_instrumentation!
    (@@detailed_request_loggers ||= []) << callback
  end

  def self.unregister_detailed_request_logger(callback)
    @@detailed_request_loggers.delete(callback)
    if @@detailed_request_loggers.length == 0
      @detailed_request_loggers = nil
    end
  end

  # used for testing
  def self.unregister_ip_skipper
    @@ip_skipper = nil
  end

  # Register a custom `ip_skipper`, a function that will skip rate limiting
  # for any IP that returns true.
  #
  # For example, if you never wanted to rate limit 1.2.3.4
  #
  # ```
  # Middleware::RequestTracker.register_ip_skipper do |ip|
  #  ip == "1.2.3.4"
  # end
  # ```
  def self.register_ip_skipper(&blk)
    raise "IP skipper is already registered!" if @@ip_skipper
    @@ip_skipper = blk
  end

  def self.ip_skipper
    @@ip_skipper
  end

  def initialize(app, settings = {})
    @app = app
  end

  def self.log_request(data)
    status = data[:status]
    track_view = data[:track_view]

    if track_view
      if data[:is_crawler]
        ApplicationRequest.increment!(:page_view_crawler)
        WebCrawlerRequest.increment!(data[:user_agent])
      elsif data[:has_auth_cookie]
        ApplicationRequest.increment!(:page_view_logged_in)
        ApplicationRequest.increment!(:page_view_logged_in_mobile) if data[:is_mobile]
      elsif !SiteSetting.login_required
        ApplicationRequest.increment!(:page_view_anon)
        ApplicationRequest.increment!(:page_view_anon_mobile) if data[:is_mobile]
      end
    end

    ApplicationRequest.increment!(:http_total)

    if status >= 500
      ApplicationRequest.increment!(:http_5xx)
    elsif data[:is_background]
      ApplicationRequest.increment!(:http_background)
    elsif status >= 400
      ApplicationRequest.increment!(:http_4xx)
    elsif status >= 300
      ApplicationRequest.increment!(:http_3xx)
    elsif status >= 200
      ApplicationRequest.increment!(:http_2xx)
    end
  end

  def self.get_data(env, result, timing)
    status, headers = result
    status = status.to_i

    helper = Middleware::AnonymousCache::Helper.new(env)
    request = Rack::Request.new(env)

    env_track_view = env["HTTP_DISCOURSE_TRACK_VIEW"]
    track_view = status == 200
    track_view &&= env_track_view != "0" && env_track_view != "false"
    track_view &&= env_track_view || (request.get? && !request.xhr? && headers["Content-Type"] =~ /text\/html/)
    track_view = !!track_view
    has_auth_cookie = Auth::DefaultCurrentUserProvider.find_v0_auth_cookie(request).present?
    has_auth_cookie ||= Auth::DefaultCurrentUserProvider.find_v1_auth_cookie(env).present?

    h = {
      status: status,
      is_crawler: helper.is_crawler?,
      has_auth_cookie: has_auth_cookie,
      is_background: !!(request.path =~ /^\/message-bus\// || request.path =~ /\/topics\/timings/),
      is_mobile: helper.is_mobile?,
      track_view: track_view,
      timing: timing,
      queue_seconds: env['REQUEST_QUEUE_SECONDS']
    }

    if h[:is_crawler]
      user_agent = env['HTTP_USER_AGENT']
      if user_agent && (user_agent.encoding != Encoding::UTF_8)
        user_agent = user_agent.encode("utf-8")
        user_agent.scrub!
      end
      h[:user_agent] = user_agent
    end

    if cache = headers["X-Discourse-Cached"]
      h[:cache] = cache
    end

    h
  end

  def log_request_info(env, result, info)
    # we got to skip this on error ... its just logging
    data = self.class.get_data(env, result, info) rescue nil

    if data
      if result && (headers = result[1])
        headers["X-Discourse-TrackView"] = "1" if data[:track_view]
      end

      if @@detailed_request_loggers
        @@detailed_request_loggers.each { |logger| logger.call(env, data) }
      end

      log_later(data)
    end
  end

  def self.populate_request_queue_seconds!(env)
    if !env['REQUEST_QUEUE_SECONDS']
      if queue_start = env['HTTP_X_REQUEST_START']
        queue_start = if queue_start.start_with?("t=")
          queue_start.split("t=")[1].to_f
        else
          queue_start.to_f / 1000.0
        end
        queue_time = (Time.now.to_f - queue_start)
        env['REQUEST_QUEUE_SECONDS'] = queue_time
      end
    end
  end

  def call(env)
    result = nil
    info = nil

    # doing this as early as possible so we have an
    # accurate counter
    ::Middleware::RequestTracker.populate_request_queue_seconds!(env)

    request = Rack::Request.new(env)

    cookie = find_auth_cookie(env)
    limiter = RequestsRateLimiter.new(
      user_id: cookie&.dig(:user_id),
      trust_level: cookie&.dig(:trust_level),
      request: request
    )
    limiter.apply_limits! do
      env["discourse.request_tracker"] = self

      MethodProfiler.start
      result = @app.call(env)
      info = MethodProfiler.stop

      # possibly transferred?
      if info && (headers = result[1])
        headers["X-Runtime"] = "%0.6f" % info[:total_duration]

        if GlobalSetting.enable_performance_http_headers
          if redis = info[:redis]
            headers["X-Redis-Calls"] = redis[:calls].to_s
            headers["X-Redis-Time"] = "%0.6f" % redis[:duration]
          end
          if sql = info[:sql]
            headers["X-Sql-Calls"] = sql[:calls].to_s
            headers["X-Sql-Time"] = "%0.6f" % sql[:duration]
          end
          if queue = env['REQUEST_QUEUE_SECONDS']
            headers["X-Queue-Time"] = "%0.6f" % queue
          end
        end
      end

      if env[Auth::DefaultCurrentUserProvider::BAD_TOKEN] && (headers = result[1])
        headers['Discourse-Logged-Out'] = '1'
      end

      result
    end
  ensure
    if !env["discourse.request_tracker.skip"]
      log_request_info(env, result, info)
    end
  end

  def log_later(data)
    Scheduler::Defer.later("Track view") do
      unless Discourse.pg_readonly_mode?
        self.class.log_request(data)
      end
    end
  end

  def find_auth_cookie(env)
    cookie = Auth::DefaultCurrentUserProvider.find_v1_auth_cookie(env)
    if cookie && cookie[:issued_at] >= max_cookie_age.ago.to_i
      cookie
    end
  end

  def max_cookie_age
    UserAuthToken::ROTATE_TIME + 1.minute
  end
end
