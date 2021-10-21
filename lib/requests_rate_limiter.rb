# frozen_string_literal: true

class RequestsRateLimiter
  attr_reader :current_user, :request

  def initialize(user, request)
    @current_user = user
    @request = request
  end

  def apply_limits!
    skip_global = skip_global_limits?
    if !skip_global
      if failed_limiter = check_global_limits!
        if warn_mode?
          log_warning(failed_limiter)
        end
        if block_mode?
          return error_response(failed_limiter)
        end
      end
    end

    failed_api_limiter = check_admin_api_key_limits! || check_user_api_key_limits!
    return error_response(failed_api_limiter) if failed_api_limiter

    rollback_incorrect_limiters = true
    yield
  ensure
    if rollback_incorrect_limiters && !skip_global
      if request.env['DISCOURSE_IS_ASSET_PATH']
        limiter_10_secs.rollback!
        limiter_60_mins.rollback!
      else
        assets_limiter_10_secs.rollback!
      end
    end
  end

  def skip_global_limits?
    return true if !block_mode? && !warn_mode?

    ip = request.ip
    return true if !GlobalSetting.max_reqs_rate_limit_on_private && is_private_ip?(ip)
    return true if Middleware::RequestTracker.ip_skipper&.call(ip)
    return true if Middleware::RequestTracker::STATIC_IP_SKIPPER&.any? { |s| s.include?(ip) }
    false
  end

  def check_global_limits!
    # we don't know whether the request is an assets request or normal request
    # at this early stage, so we bump/check all rate limiters. We will find out
    # the request type after the app is called and we will then
    # decrement/rollback the wrong limiters that we've bumped earlier.
    limiter = limiter_10_secs
    limiter.performed!

    limiter = limiter_60_mins
    limiter.performed!

    limiter = assets_limiter_10_secs
    limiter.performed!

    nil
  rescue RateLimiter::LimitExceeded
    limiter
  end

  def check_user_api_key_limits!
    return if !user_api_key_request?

    limiter = user_api_key_limiter_1_day
    limiter.performed!

    limiter = user_api_key_limiter_60_mins
    limiter.performed!
    nil
  rescue RateLimiter::LimitExceeded
    limiter
  end

  def check_admin_api_key_limits!
    return if Rails.env.profile? || !admin_api_key_request?

    admin_api_key_limiter.performed!
    nil
  rescue RateLimiter::LimitExceeded
    admin_api_key_limiter
  end

  def block_mode?
    GlobalSetting.max_reqs_per_ip_mode == "block" ||
      GlobalSetting.max_reqs_per_ip_mode == "warn+block"
  end

  def warn_mode?
    GlobalSetting.max_reqs_per_ip_mode == "warn" ||
      GlobalSetting.max_reqs_per_ip_mode == "warn+block"
  end

  def is_private_ip?(ip)
    ip = IPAddr.new(ip) rescue nil
    !!(ip && (ip.private? || ip.loopback?))
  end

  def limiter_10_secs
    return @limiter_10_secs if @limiter_10_secs

    @limiter_10_secs = RateLimiter.new(
      nil,
      "global_ip_limit_10_#{user_ip_or_id}",
      GlobalSetting.max_reqs_per_ip_per_10_seconds,
      10,
      global: true,
      aggressive: true
    )
  end

  def limiter_60_mins
    return @limiter_60_mins if @limiter_60_mins

    @limiter_60_mins = RateLimiter.new(
      nil,
      "global_ip_limit_60_#{user_ip_or_id}",
      GlobalSetting.max_reqs_per_ip_per_minute,
      60,
      global: true,
      aggressive: true
    )
  end

  def assets_limiter_10_secs
    return @assets_limiter_10_secs if @assets_limiter_10_secs

    @assets_limiter_10_secs = RateLimiter.new(
      nil,
      "global_ip_limit_10_assets_#{user_ip_or_id}",
      GlobalSetting.max_asset_reqs_per_ip_per_10_seconds,
      10,
      global: true
    )
  end

  def admin_api_key_limiter
    return @admin_api_key_limiter if @admin_api_key_limiter

    limit = GlobalSetting.max_admin_api_reqs_per_minute.to_i
    if GlobalSetting.respond_to?(:max_admin_api_reqs_per_key_per_minute)
      Discourse.deprecate("DISCOURSE_MAX_ADMIN_API_REQS_PER_KEY_PER_MINUTE is deprecated. Please use DISCOURSE_MAX_ADMIN_API_REQS_PER_MINUTE")
      limit = [
        GlobalSetting.max_admin_api_reqs_per_key_per_minute.to_i,
        limit
      ].max
    end
    @admin_api_key_limiter = RateLimiter.new(
      nil,
      "admin_api_min",
      limit,
      60
    )
  end

  def user_api_key_limiter_60_mins
    return @user_api_key_limiter_60_mins if @user_api_key_limiter_60_mins

    hashed_user_api_key = ApiKey.hash_key(
      request.env[Auth::DefaultCurrentUserProvider::USER_API_KEY]
    )
    @user_api_key_limiter_60_mins = RateLimiter.new(
      nil,
      "user_api_min_#{hashed_user_api_key}",
      GlobalSetting.max_user_api_reqs_per_minute,
      60
    )
  end

  def user_api_key_limiter_1_day
    return @user_api_key_limiter_1_day if @user_api_key_limiter_1_day

    hashed_user_api_key = ApiKey.hash_key(
      request.env[Auth::DefaultCurrentUserProvider::USER_API_KEY]
    )
    @user_api_key_limiter_1_day = RateLimiter.new(
      nil,
      "user_api_day_#{hashed_user_api_key}",
      GlobalSetting.max_user_api_reqs_per_day,
      86400
    )
  end

  def user_ip_or_id
    limit_on_user_id? ? current_user.id : request.ip
  end

  def limit_on_user_id?
    current_user &&
      current_user.trust_level >= GlobalSetting.skip_per_ip_rate_limit_trust_level &&
      !shared_session_request? &&
      !admin_api_key_request? &&
      !user_api_key_request?
  end

  def admin_api_key_request?
    request.env[Auth::DefaultCurrentUserProvider::API_KEY_ENV]
  end

  def user_api_key_request?
    request.env[Auth::DefaultCurrentUserProvider::USER_API_KEY_ENV]
  end

  def shared_session_request?
    request.env[Auth::DefaultCurrentUserProvider::SHARED_SESSION_ENV]
  end

  def log_warning(limiter)
    if limiter == limiter_10_secs
      Discourse.warn(
        "Global IP rate limit exceeded for #{user_ip_or_id}: 10 seconds rate limit",
        uri: request.env["REQUEST_URI"]
      )
    elsif limiter == limiter_60_mins
      Discourse.warn(
        "Global IP rate limit exceeded for #{user_ip_or_id}: 60 minutes rate limit",
        uri: request.env["REQUEST_URI"]
      )
    elsif limiter == assets_limiter_10_secs
      Discourse.warn(
        "Global asset IP rate limit exceeded for #{user_ip_or_id}: 10 second rate limit",
        uri: request.env["REQUEST_URI"]
      )
    end
  end

  def error_response(limiter)
    wait_secs = limiter.seconds_to_wait
    headers = { "Retry-After" => wait_secs.to_s }

    if limiter == limiter_10_secs
      error_id = "ip_or_id_10_secs_limit"
    elsif limiter == limiter_60_mins
      error_id = "ip_or_id_60_mins_limit"
    elsif limiter == assets_limiter_10_secs
      error_id = "ip_or_id_assets_10_secs_limit"
    elsif limiter == admin_api_key_limiter
      error_id = "admin_api_key_rate_limit"
      message = json_error_response(error_id, wait_secs, headers)
    elsif limiter == user_api_key_limiter_60_mins
      error_id = "user_api_key_rate_limit_60_mins"
      message = json_error_response(error_id, wait_secs, headers)
    elsif limiter == user_api_key_limiter_1_day
      error_id = "user_api_key_rate_limit_1_day"
      message = json_error_response(error_id, wait_secs, headers)
    end

    headers["Discourse-Rate-Limit-Error-Id"] = error_id || "<unset>"
    headers["Content-Type"] ||= "text/plain; charset=utf-8"
    if !message
      message = "Slow down, too many requests from this IP address.\n"
      message += "Please retry again in #{wait_secs} seconds.\n"
      message += "Error id: #{error_id}."
    end
    [429, headers, [message]]
  end

  def json_error_response(error_id, wait_secs, headers)
    headers["Content-Type"] = "application/json; charset=utf-8"
    {
      errors: [
        "You've performed this action too many times. Please wait #{wait_secs} seconds before trying again."
      ],
      error_type: "rate_limit",
      error_id: error_id,
      extras: {
        wait_seconds: wait_secs
      }
    }.to_json
  end
end
