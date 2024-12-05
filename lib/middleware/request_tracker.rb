# frozen_string_literal: true

require "method_profiler"
require "middleware/anonymous_cache"
require "http_user_agent_encoder"

class Middleware::RequestTracker
  @@detailed_request_loggers = nil
  @@ip_skipper = nil
  @@bucketizers = []
  def self.bucketizers
    @@bucketizers.map { { priority: _1[0], identifier: _1[1] } }
  end

  # You can add exceptions to our app rate limiter in the app.yml ENV section.
  # example:
  #
  # env:
  #   DISCOURSE_MAX_REQS_PER_IP_EXCEPTIONS: >-
  #     14.15.16.32/27
  #     216.148.1.2
  #
  STATIC_IP_SKIPPER =
    ENV["DISCOURSE_MAX_REQS_PER_IP_EXCEPTIONS"]&.split&.map { |ip| IPAddr.new(ip) }

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
    @detailed_request_loggers = nil if @@detailed_request_loggers.length == 0
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
    if data[:is_api]
      ApplicationRequest.increment!(:api)
    elsif data[:is_user_api]
      ApplicationRequest.increment!(:user_api)
    elsif data[:track_view]
      if data[:is_crawler]
        ApplicationRequest.increment!(:page_view_crawler)
        WebCrawlerRequest.increment!(data[:user_agent])
      elsif data[:has_auth_cookie]
        ApplicationRequest.increment!(:page_view_logged_in)
        ApplicationRequest.increment!(:page_view_logged_in_mobile) if data[:is_mobile]

        if data[:explicit_track_view]
          # Must be a browser if it had this header from our ajax implementation
          ApplicationRequest.increment!(:page_view_logged_in_browser)
          ApplicationRequest.increment!(:page_view_logged_in_browser_mobile) if data[:is_mobile]

          if data[:topic_id].present? && data[:current_user_id].present?
            TopicsController.defer_topic_view(
              data[:topic_id],
              data[:request_remote_ip],
              data[:current_user_id],
            )
          end
        end
      elsif !SiteSetting.login_required
        ApplicationRequest.increment!(:page_view_anon)
        ApplicationRequest.increment!(:page_view_anon_mobile) if data[:is_mobile]

        if data[:explicit_track_view]
          # Must be a browser if it had this header from our ajax implementation
          ApplicationRequest.increment!(:page_view_anon_browser)
          ApplicationRequest.increment!(:page_view_anon_browser_mobile) if data[:is_mobile]

          if data[:topic_id].present?
            TopicsController.defer_topic_view(data[:topic_id], data[:request_remote_ip])
          end
        end
      end
    end

    # Message-bus requests may include this 'deferred track' header which we use to detect
    # 'real browser' views.
    if data[:deferred_track] && !data[:is_crawler]
      if data[:has_auth_cookie]
        ApplicationRequest.increment!(:page_view_logged_in_browser)
        ApplicationRequest.increment!(:page_view_logged_in_browser_mobile) if data[:is_mobile]

        if data[:topic_id].present? && data[:current_user_id].present?
          TopicsController.defer_topic_view(
            data[:topic_id],
            data[:request_remote_ip],
            data[:current_user_id],
          )
        end
      elsif !SiteSetting.login_required
        ApplicationRequest.increment!(:page_view_anon_browser)
        ApplicationRequest.increment!(:page_view_anon_browser_mobile) if data[:is_mobile]

        if data[:topic_id].present?
          TopicsController.defer_topic_view(data[:topic_id], data[:request_remote_ip])
        end
      end
    end

    ApplicationRequest.increment!(:http_total)

    status = data[:status]
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

  def self.get_data(env, result, timing, request = nil)
    status, headers = result

    # result may be nil if the downstream app raised an exception
    status = status.to_i
    headers ||= {}

    request ||= Rack::Request.new(env)
    helper = Middleware::AnonymousCache::Helper.new(env, request)

    # Since ActionDispatch::RemoteIp middleware is run before this middleware,
    # we have access to the normalised remote IP based on ActionDispatch::RemoteIp::GetIp
    #
    # NOTE: Locally with MessageBus requests, the remote IP ends up as ::1 because
    # of the X-Forwarded-For header set...somewhere, whereas all other requests
    # end up as 127.0.0.1.
    request_remote_ip = env["action_dispatch.remote_ip"].to_s

    # Value of the discourse-track-view request header, set in `lib/ajax.js`
    env_track_view = env["HTTP_DISCOURSE_TRACK_VIEW"]

    # Was the discourse-track-view request header set to true? Likely
    # set by our ajax library to indicate a page view.
    explicit_track_view = status == 200 && %w[1 true].include?(env_track_view)

    # An HTML response to a GET request is tracked implicitly
    implicit_track_view =
      status == 200 && !%w[0 false].include?(env_track_view) && request.get? && !request.xhr? &&
        headers["Content-Type"] =~ %r{text/html}

    # This header is sent on a follow-up request after a real browser loads up a page
    # see `scripts/pageview.js` and `instance-initializers/page-tracking.js`
    deferred_track_view = %w[1 true].include?(env["HTTP_DISCOURSE_DEFERRED_TRACK_VIEW"])

    # This is treated separately from deferred tracking in #log_request, this is
    # why deferred_track_view is not counted here.
    track_view = !!(explicit_track_view || implicit_track_view)

    # These are set in the same place as the respective track view headers in the client.
    topic_id =
      if deferred_track_view
        env["HTTP_DISCOURSE_DEFERRED_TRACK_VIEW_TOPIC_ID"]
      elsif explicit_track_view || implicit_track_view
        env["HTTP_DISCOURSE_TRACK_VIEW_TOPIC_ID"]
      end

    auth_cookie = Auth::DefaultCurrentUserProvider.find_v0_auth_cookie(request)
    auth_cookie ||= Auth::DefaultCurrentUserProvider.find_v1_auth_cookie(env)
    has_auth_cookie = auth_cookie.present?

    is_api ||= !!env[Auth::DefaultCurrentUserProvider::API_KEY_ENV]
    is_user_api ||= !!env[Auth::DefaultCurrentUserProvider::USER_API_KEY_ENV]

    is_message_bus = request.path.start_with?("#{Discourse.base_path}/message-bus/")
    is_topic_timings = request.path.start_with?("#{Discourse.base_path}/topics/timings")

    # Auth cookie can be used to find the ID for logged in users, but API calls must look up the
    # current user based on env variables.
    #
    # We only care about this for topic views, other pageviews it's enough to know if the user is
    # logged in or not, and we have separate pageview tracking for API views.
    current_user_id =
      if topic_id.present?
        begin
          (auth_cookie&.[](:user_id) || CurrentUser.lookup_from_env(env)&.id)
        rescue Discourse::InvalidAccess => err
          # This error is raised when the API key is invalid, no need to stop the show.
          Discourse.warn_exception(
            err,
            message: "RequestTracker.get_data failed with an invalid API key error",
          )
          nil
        end
      end

    h = {
      status: status,
      is_crawler: helper.is_crawler?,
      has_auth_cookie: has_auth_cookie,
      current_user_id: current_user_id,
      topic_id: topic_id,
      is_api: is_api,
      is_user_api: is_user_api,
      is_background: is_message_bus || is_topic_timings,
      is_mobile: helper.is_mobile?,
      track_view: track_view,
      timing: timing,
      queue_seconds: env["REQUEST_QUEUE_SECONDS"],
      explicit_track_view: explicit_track_view,
      deferred_track: deferred_track_view,
      request_remote_ip: request_remote_ip,
    }

    if h[:is_background]
      h[:background_type] = if is_message_bus
        if request.query_string.include?("dlp=t")
          "message-bus-dlp"
        elsif env["HTTP_DONT_CHUNK"]
          "message-bus-dontchunk"
        else
          "message-bus"
        end
      else
        "topic-timings"
      end
    end

    if h[:is_crawler]
      user_agent = env["HTTP_USER_AGENT"]
      user_agent = HttpUserAgentEncoder.ensure_utf8(user_agent) if user_agent
      h[:user_agent] = user_agent
    end

    if cache = headers["X-Discourse-Cached"]
      h[:cache] = cache
    end

    h
  end

  def log_request_info(env, result, info, request = nil)
    # We've got to skip this on error ... its just logging
    data =
      begin
        self.class.get_data(env, result, info, request)
      rescue StandardError => err
        Discourse.warn_exception(err, message: "RequestTracker.get_data failed")

        # This is super hard to find if in testing, we should still raise in this case.
        raise err if Rails.env.test?

        nil
      end

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
    if !env["REQUEST_QUEUE_SECONDS"]
      if queue_start = env["HTTP_X_REQUEST_START"]
        queue_start =
          if queue_start.start_with?("t=")
            queue_start.split("t=")[1].to_f
          else
            queue_start.to_f / 1000.0
          end
        queue_time = (Time.now.to_f - queue_start)
        env["REQUEST_QUEUE_SECONDS"] = queue_time
      end
    end
  end

  def call(env)
    result = nil
    info = nil
    gc_stat_timing = nil

    # doing this as early as possible so we have an
    # accurate counter
    ::Middleware::RequestTracker.populate_request_queue_seconds!(env)

    request = Rack::Request.new(env)

    cookie = find_auth_cookie(env)
    if error_details = rate_limit(request, cookie)
      available_in, error_code, bucket_description = error_details
      message = <<~TEXT
        Slow down, too many requests from this #{bucket_description}.
        Please retry again in #{available_in} seconds.
        Error code: #{error_code}.
      TEXT
      headers = {
        "Content-Type" => "text/plain",
        "Retry-After" => available_in.to_s,
        "Discourse-Rate-Limit-Error-Code" => error_code,
      }
      if username = cookie&.[](:username)
        headers["X-Discourse-Username"] = username
      end
      return 429, headers, [message]
    end

    if !cookie
      if error_details = check_crawler_limits(env)
        available_in, error_code = error_details
        message = "Too many crawling requests. Error code: #{error_code}."
        headers = {
          "Content-Type" => "text/plain",
          "Retry-After" => available_in.to_s,
          "Discourse-Rate-Limit-Error-Code" => error_code,
        }
        return 429, headers, [message]
      end
    end

    env["discourse.request_tracker"] = self

    MethodProfiler.start

    if SiteSetting.instrument_gc_stat_per_request
      gc_stat_timing = GCStatInstrumenter.instrument { result = @app.call(env) }
    else
      result = @app.call(env)
    end

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
        if queue = env["REQUEST_QUEUE_SECONDS"]
          headers["X-Queue-Time"] = "%0.6f" % queue
        end
      end
    end

    if env[Auth::DefaultCurrentUserProvider::BAD_TOKEN] && (headers = result[1])
      headers["Discourse-Logged-Out"] = "1"
    end

    result
  ensure
    if (limiters = env["DISCOURSE_RATE_LIMITERS"]) && env["DISCOURSE_IS_ASSET_PATH"]
      limiters.each(&:rollback!)
      env["DISCOURSE_ASSET_RATE_LIMITERS"].each do |limiter|
        begin
          limiter.performed!
        rescue RateLimiter::LimitExceeded
          # skip
        end
      end
    end

    if !env["discourse.request_tracker.skip"]
      info.merge!(gc_stat_timing) if gc_stat_timing
      log_request_info(env, result, info, request)
    end
  end

  def log_later(data)
    Scheduler::Defer.later("Track view") do
      self.class.log_request(data) unless Discourse.pg_readonly_mode?
    end
  end

  def find_auth_cookie(env)
    min_allowed_timestamp = Time.now.to_i - (UserAuthToken::ROTATE_TIME_MINS + 1) * 60
    cookie = Auth::DefaultCurrentUserProvider.find_v1_auth_cookie(env)
    cookie if cookie && cookie[:issued_at] >= min_allowed_timestamp
  end

  def self.rate_limit_bucketizer_register(priority:, identifier:, blk:)
    new_list = @@bucketizers.dup.delete_if { _1[1] == identifier }
    new_list.unshift([priority, identifier, blk])
    @@bucketizers = new_list.sort_by { _1[0] } # priority
  end

  def self.rate_limit_bucketizer_unregister(identifier:)
    @@bucketizers.delete_if { _1[1] == identifier }
  end

  def rate_limit_bucket_for_request(request, cookie)
    # returns: [
    #   bucket,                   # the specific bucket value, i.e. IP address / username / something else
    #   global?,                  # is this limiter global across sites?
    #   short bucket description, # short type of the bucket, i.e. "ip", "id", "cloud"
    #   long bucket description,  # type of the bucket, intended for human eyes
    # ] | :skip

    return :skip if @@ip_skipper&.call(request.ip)

    @@bucketizers.each do |priority, identifier, blk|
      result = blk.call(request, cookie)
      return result unless result.nil?
    end

    :skip
  end

  def rate_limit(request, cookie)
    warn =
      GlobalSetting.max_reqs_per_ip_mode == "warn" ||
        GlobalSetting.max_reqs_per_ip_mode == "warn+block"
    block =
      GlobalSetting.max_reqs_per_ip_mode == "block" ||
        GlobalSetting.max_reqs_per_ip_mode == "warn+block"

    return if !block && !warn

    bucket, global, desc, description = rate_limit_bucket_for_request(request, cookie)

    return if bucket == :skip # -> do not rate limit

    limiter10 =
      RateLimiter.new(
        nil,
        "global_limit_10_#{bucket}",
        GlobalSetting.max_reqs_per_ip_per_10_seconds,
        10,
        global: global,
        aggressive: true,
        error_code: "#{desc}_10_secs_limit",
      )

    limiter60 =
      RateLimiter.new(
        nil,
        "global_limit_60_#{bucket}",
        GlobalSetting.max_reqs_per_ip_per_minute,
        60,
        global: global,
        error_code: "#{desc}_60_secs_limit",
        aggressive: true,
      )

    limiter_assets10 =
      RateLimiter.new(
        nil,
        "global_limit_10_assets_#{bucket}",
        GlobalSetting.max_asset_reqs_per_ip_per_10_seconds,
        10,
        error_code: "#{desc}_assets_10_secs_limit",
        global: global,
      )

    request.env["DISCOURSE_RATE_LIMITERS"] = [limiter10, limiter60]
    request.env["DISCOURSE_ASSET_RATE_LIMITERS"] = [limiter_assets10]

    if !limiter_assets10.can_perform?
      if warn
        Discourse.warn(
          "Global asset rate limit exceeded for #{desc}: #{bucket}: 10 second rate limit",
          uri: request.env["REQUEST_URI"],
        )
      end

      if block
        return [
          limiter_assets10.seconds_to_wait(Time.now.to_i),
          limiter_assets10.error_code,
          description
        ]
      end
    end

    begin
      type = 10
      limiter10.performed!

      type = 60
      limiter60.performed!

      nil
    rescue RateLimiter::LimitExceeded => e
      if warn
        Discourse.warn(
          "Global rate limit exceeded for #{desc}: #{bucket}: #{type} second rate limit",
          uri: request.env["REQUEST_URI"],
        )
      end
      if block
        [e.available_in, e.error_code, description]
      else
        nil
      end
    end
  end

  def check_crawler_limits(env)
    slow_down_agents = SiteSetting.slow_down_crawler_user_agents
    return if slow_down_agents.blank?

    user_agent = HttpUserAgentEncoder.ensure_utf8(env["HTTP_USER_AGENT"])&.downcase
    return if user_agent.blank?

    return if !CrawlerDetection.crawler?(user_agent)

    slow_down_agents
      .downcase
      .split("|")
      .each do |crawler|
        if user_agent.include?(crawler)
          key = "#{crawler}_crawler_rate_limit"
          limiter =
            RateLimiter.new(nil, key, 1, SiteSetting.slow_down_crawler_rate, error_code: key)
          limiter.performed!
          break
        end
      end
    nil
  rescue RateLimiter::LimitExceeded => e
    [e.available_in, e.error_code]
  end
end
