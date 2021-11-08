# frozen_string_literal: true

class RequestsRateLimiter
  attr_reader :user_id, :trust_level, :request

  def initialize(user_id: nil, trust_level: nil, request:)
    @user_id = user_id
    @trust_level = trust_level
    @request = request
  end

  def apply_limits!
    return yield if skip_limits?

    if failed_limiter = check_limits!
      if warn_mode?
        log_warning(failed_limiter)
      end
      if block_mode?
        return error_response(failed_limiter)
      end
    end

    rollback_incorrect_limiters = true
    yield
  ensure
    if rollback_incorrect_limiters
      if request.env['DISCOURSE_IS_ASSET_PATH']
        limiter_10_secs.rollback!
        limiter_60_secs.rollback!
      else
        assets_limiter_10_secs.rollback!
      end
    end
  end

  def skip_limits?
    return true if !block_mode? && !warn_mode?

    ip = request.ip
    return true if !GlobalSetting.max_reqs_rate_limit_on_private && is_private_ip?(ip)
    return true if Middleware::RequestTracker.ip_skipper&.call(ip)
    return true if Middleware::RequestTracker::STATIC_IP_SKIPPER&.any? { |s| s.include?(ip) }
    false
  end

  def check_limits!
    # we don't know whether the request is an assets request or normal request
    # at this early stage, so we bump/check all rate limiters. We will find out
    # the request type after the app is called and we will then
    # decrement/rollback the wrong limiters that we've bumped earlier.
    limiter = limiter_10_secs
    limiter.performed!

    limiter = limiter_60_secs
    limiter.performed!

    limiter = assets_limiter_10_secs
    limiter.performed!

    nil
  rescue RateLimiter::LimitExceeded
    limiter
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
    ip = IPAddr.new(ip)
    !!(ip && (ip.private? || ip.loopback?))
  rescue IPAddr::AddressFamilyError, IPAddr::InvalidAddressError
    false
  end

  def limiter_10_secs
    return @limiter_10_secs if @limiter_10_secs

    error_code = limit_on_user_id? ? "id_10_secs_limit" : "ip_10_secs_limit"
    @limiter_10_secs = RateLimiter.new(
      nil,
      "global_ip_limit_10_#{user_ip_or_id}",
      GlobalSetting.max_reqs_per_ip_per_10_seconds,
      10,
      global: !limit_on_user_id?,
      aggressive: true,
      error_code: error_code
    )
  end

  def limiter_60_secs
    return @limiter_60_secs if @limiter_60_secs

    error_code = limit_on_user_id? ? "id_60_secs_limit" : "ip_60_secs_limit"
    @limiter_60_secs = RateLimiter.new(
      nil,
      "global_ip_limit_60_#{user_ip_or_id}",
      GlobalSetting.max_reqs_per_ip_per_minute,
      60,
      global: !limit_on_user_id?,
      aggressive: true,
      error_code: error_code
    )
  end

  def assets_limiter_10_secs
    return @assets_limiter_10_secs if @assets_limiter_10_secs

    error_code = limit_on_user_id? ? "id_assets_10_secs_limit" : "ip_assets_10_secs_limit"
    @assets_limiter_10_secs = RateLimiter.new(
      nil,
      "global_ip_limit_10_assets_#{user_ip_or_id}",
      GlobalSetting.max_asset_reqs_per_ip_per_10_seconds,
      10,
      global: limit_on_user_id?,
      error_code: error_code
    )
  end

  def user_ip_or_id
    limit_on_user_id? ? user_id : request.ip
  end

  def limit_on_user_id?
    return false if !user_id || !trust_level
    trust_level >= GlobalSetting.skip_per_ip_rate_limit_trust_level
  end

  def log_warning(limiter)
    type = limit_on_user_id? ? "user id" : "IP"
    if limiter == limiter_10_secs
      Discourse.warn(
        "Global rate limit exceeded for #{type} #{user_ip_or_id}: 10 seconds rate limit",
        uri: request.env["REQUEST_URI"]
      )
    elsif limiter == limiter_60_secs
      Discourse.warn(
        "Global rate limit exceeded for #{type} #{user_ip_or_id}: 60 seconds rate limit",
        uri: request.env["REQUEST_URI"]
      )
    elsif limiter == assets_limiter_10_secs
      Discourse.warn(
        "Global asset rate limit exceeded for #{type} #{user_ip_or_id}: 10 second rate limit",
        uri: request.env["REQUEST_URI"]
      )
    end
  end

  def error_response(limiter)
    wait_secs = limiter.seconds_to_wait
    headers = {
      "Retry-After" => wait_secs.to_s,
      "Discourse-Rate-Limit-Error-Code" => limiter.error_code,
      "Content-Type" => "text/plain; charset=utf-8"
    }
    message = <<~TEXT
      Slow down, too many requests from this IP address.
      Please retry again in #{wait_secs} seconds.
      Error code: #{limiter.error_code}.
    TEXT

    [429, headers, [message]]
  end
end
