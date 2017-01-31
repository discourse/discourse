require_dependency "auth/current_user_provider"
require_dependency "rate_limiter"

class Auth::DefaultCurrentUserProvider

  CURRENT_USER_KEY ||= "_DISCOURSE_CURRENT_USER".freeze
  API_KEY ||= "api_key".freeze
  USER_API_KEY ||= "HTTP_USER_API_KEY".freeze
  USER_API_CLIENT_ID ||= "HTTP_USER_API_CLIENT_ID".freeze
  API_KEY_ENV ||= "_DISCOURSE_API".freeze
  USER_API_KEY_ENV ||= "_DISCOURSE_USER_API".freeze
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
        @user_token = UserAuthToken.lookup(auth_token, seen: true)
        current_user = @user_token.try(:user)
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

      current_user = lookup_user_api_user_and_update_key(api_key, @env[USER_API_CLIENT_ID])
      raise Discourse::InvalidAccess unless current_user

      limiter_min.performed!
      limiter_day.performed!

      @env[USER_API_KEY_ENV] = true
    end

    @env[CURRENT_USER_KEY] = current_user
  end

  def refresh_session(user, session, cookies)

    # if user was not loaded, no point refreshing session
    # it could be an anonymous path, this would add cost
    return if is_api? || !@env.key?(CURRENT_USER_KEY)

    if @user_token && @user_token.user == user
      rotated_at = @user_token.rotated_at

      needs_rotation = @user_token.auth_token_seen ? rotated_at < UserAuthToken::ROTATE_TIME.ago : rotated_at < UserAuthToken::URGENT_ROTATE_TIME.ago

      if !@user_token.legacy && needs_rotation
        if @user_token.rotate!(user_agent: @env['HTTP_USER_AGENT'],
                              client_ip: @request.ip)
          cookies[TOKEN_COOKIE] = cookie_hash(@user_token.unhashed_auth_token)
        end
      elsif @user_token.legacy
        # make a new token
        log_on_user(user, session, cookies)
      end
    end

    if !user && cookies.key?(TOKEN_COOKIE)
      cookies.delete(TOKEN_COOKIE)
    end
  end

  def log_on_user(user, session, cookies)
    @user_token = UserAuthToken.generate!(user_id: user.id,
                                          user_agent: @env['HTTP_USER_AGENT'],
                                          client_ip: @request.ip)

    cookies[TOKEN_COOKIE] = cookie_hash(@user_token.unhashed_auth_token)
    make_developer_admin(user)
    enable_bootstrap_mode(user)
    @env[CURRENT_USER_KEY] = user
  end

  def cookie_hash(unhashed_auth_token)
    {
      value: unhashed_auth_token,
      httponly: true,
      expires: SiteSetting.maximum_session_age.hours.from_now,
      secure: SiteSetting.force_https
    }
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
    user = current_user
    if SiteSetting.log_out_strict && user
      user.user_auth_tokens.destroy_all

      if user.admin && defined?(Rack::MiniProfiler)
        # clear the profiling cookie to keep stuff tidy
        cookies.delete("__profilin")
      end

      user.logged_out
    elsif user && @user_token
      @user_token.destroy
    end
    cookies.delete(TOKEN_COOKIE)
  end


  # api has special rights return true if api was detected
  def is_api?
    current_user
    !!(@env[API_KEY_ENV])
  end

  def is_user_api?
    current_user
    !!(@env[USER_API_KEY_ENV])
  end

  def has_auth_cookie?
    cookie = @request.cookies[TOKEN_COOKIE]
    !cookie.nil? && cookie.length == 32
  end

  def should_update_last_seen?
    !(@request.path =~ /^\/message-bus\//)
  end

  protected

  def lookup_user_api_user_and_update_key(user_api_key, client_id)
    if api_key = UserApiKey.where(key: user_api_key, revoked_at: nil).includes(:user).first
      unless api_key.allow?(@env)
        raise Discourse::InvalidAccess
      end

      if client_id.present? && client_id != api_key.client_id
        api_key.update_columns(client_id: client_id)
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
