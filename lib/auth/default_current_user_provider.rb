require_dependency "auth/current_user_provider"
require_dependency "rate_limiter"

class Auth::DefaultCurrentUserProvider

  CURRENT_USER_KEY ||= "_DISCOURSE_CURRENT_USER".freeze
  API_KEY ||= "api_key".freeze
  USER_API_KEY ||= "HTTP_USER_API_KEY".freeze
  API_KEY_ENV ||= "_DISCOURSE_API".freeze
  TOKEN_COOKIE ||= "_t".freeze
  PATH_INFO ||= "PATH_INFO".freeze
  COOKIE_ATTEMPTS_PER_MIN ||= 10

  # do all current user initialization here
  def initialize(env)
    @env = env
    @request = Rack::Request.new(env)
  end

  # our current user, return nil if none is found
  def current_user
    return @env[CURRENT_USER_KEY] if @env.key?(CURRENT_USER_KEY)

    # bypass if we have the shared session header
    if shared_key = @env['HTTP_X_SHARED_SESSION_KEY']
      uid = $redis.get("shared_session_key_#{shared_key}")
      user = nil
      if uid
        user = User.find_by(id: uid.to_i)
      end
      @env[CURRENT_USER_KEY] = user
      return user
    end

    request = @request

    auth_token = request.cookies[TOKEN_COOKIE]

    current_user = nil

    if auth_token && auth_token.length == 32
      limiter = RateLimiter.new(nil, "cookie_auth_#{request.ip}", COOKIE_ATTEMPTS_PER_MIN ,60)

      if limiter.can_perform?
        current_user = User.where(auth_token: auth_token)
                         .where('auth_token_updated_at IS NULL OR auth_token_updated_at > ?',
                                  SiteSetting.maximum_session_age.hours.ago)
                         .first
      end

      unless current_user
        begin
          limiter.performed!
        rescue RateLimiter::LimitExceeded
          raise Discourse::InvalidAccess
        end
      end
    end

    if current_user && (current_user.suspended? || !current_user.active)
      current_user = nil
    end

    if current_user && should_update_last_seen?
      u = current_user
      Scheduler::Defer.later "Updating Last Seen" do
        u.update_last_seen!
        u.update_ip_address!(request.ip)
      end
    end

    # possible we have an api call, impersonate
    if api_key = request[API_KEY]
      current_user = lookup_api_user(api_key, request)
      raise Discourse::InvalidAccess unless current_user
      @env[API_KEY_ENV] = true
    end

    # user api key handling
    if api_key = @env[USER_API_KEY]

      limiter_min = RateLimiter.new(nil, "user_api_min_#{api_key}", SiteSetting.max_user_api_reqs_per_minute, 60)
      limiter_day = RateLimiter.new(nil, "user_api_day_#{api_key}", SiteSetting.max_user_api_reqs_per_day, 86400)

      unless limiter_day.can_perform?
        limiter_day.performed!
      end

      unless  limiter_min.can_perform?
        limiter_min.performed!
      end

      current_user = lookup_user_api_user(api_key)
      raise Discourse::InvalidAccess unless current_user

      limiter_min.performed!
      limiter_day.performed!

      @env[API_KEY_ENV] = true
    end

    @env[CURRENT_USER_KEY] = current_user
  end

  def refresh_session(user, session, cookies)
    return if is_api?

    if user && (!user.auth_token_updated_at || user.auth_token_updated_at <= 1.hour.ago)
      user.update_column(:auth_token_updated_at, Time.zone.now)
      cookies[TOKEN_COOKIE] = { value: user.auth_token, httponly: true, expires: SiteSetting.maximum_session_age.hours.from_now }
    end
    if !user && cookies.key?(TOKEN_COOKIE)
      cookies.delete(TOKEN_COOKIE)
    end
  end

  def log_on_user(user, session, cookies)
    legit_token = user.auth_token && user.auth_token.length == 32
    expired_token = user.auth_token_updated_at && user.auth_token_updated_at < SiteSetting.maximum_session_age.hours.ago

    if !legit_token || expired_token
      user.update_columns(auth_token: SecureRandom.hex(16),
                          auth_token_updated_at: Time.zone.now)
    end

    cookies[TOKEN_COOKIE] = { value: user.auth_token, httponly: true, expires: SiteSetting.maximum_session_age.hours.from_now }
    make_developer_admin(user)
    enable_bootstrap_mode(user)
    @env[CURRENT_USER_KEY] = user
  end

  def make_developer_admin(user)
    if  user.active? &&
        !user.admin &&
        Rails.configuration.respond_to?(:developer_emails) &&
        Rails.configuration.developer_emails.include?(user.email)
      user.admin = true
      user.save
    end
  end

  def enable_bootstrap_mode(user)
    Jobs.enqueue(:enable_bootstrap_mode, user_id: user.id) if user.admin && user.last_seen_at.nil? && !SiteSetting.bootstrap_mode_enabled && user.is_singular_admin?
  end

  def log_off_user(session, cookies)
    if SiteSetting.log_out_strict && (user = current_user)
      user.auth_token = nil
      user.save!

      if user.admin && defined?(Rack::MiniProfiler)
        # clear the profiling cookie to keep stuff tidy
        cookies.delete("__profilin")
      end

      user.logged_out
    end
    cookies.delete(TOKEN_COOKIE)
  end


  # api has special rights return true if api was detected
  def is_api?
    current_user
    @env[API_KEY_ENV]
  end

  def has_auth_cookie?
    cookie = @request.cookies[TOKEN_COOKIE]
    !cookie.nil? && cookie.length == 32
  end

  def should_update_last_seen?
    !(@request.path =~ /^\/message-bus\//)
  end

  protected

  WHITELISTED_WRITE_PATHS ||= [/^\/message-bus\/.*\/poll/, /^\/user-api-key\/revoke$/]
  def lookup_user_api_user(user_api_key)
    if api_key = UserApiKey.where(key: user_api_key, revoked_at: nil).includes(:user).first
      unless api_key.write
        if @env["REQUEST_METHOD"] != "GET"
          path = @env["PATH_INFO"]
          unless WHITELISTED_WRITE_PATHS.any?{|whitelisted| path =~ whitelisted}
            raise Discourse::InvalidAccess
          end
        end
      end

      api_key.user
    end
  end

  def lookup_api_user(api_key_value, request)
    if api_key = ApiKey.where(key: api_key_value).includes(:user).first
      api_username = request["api_username"]

      if api_key.allowed_ips.present? && !api_key.allowed_ips.any? { |ip| ip.include?(request.ip) }
        Rails.logger.warn("[Unauthorized API Access] username: #{api_username}, IP address: #{request.ip}")
        return nil
      end

      if api_key.user
        api_key.user if !api_username || (api_key.user.username_lower == api_username.downcase)
      elsif api_username
        User.find_by(username_lower: api_username.downcase)
      end
    end
  end

end
