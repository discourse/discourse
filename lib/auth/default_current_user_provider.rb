# frozen_string_literal: true

require_dependency "auth/current_user_provider"
require_dependency "rate_limiter"

class Auth::DefaultCurrentUserProvider

  CURRENT_USER_KEY ||= "_DISCOURSE_CURRENT_USER"
  API_KEY ||= "api_key"
  API_USERNAME ||= "api_username"
  HEADER_API_KEY ||= "HTTP_API_KEY"
  HEADER_API_USERNAME ||= "HTTP_API_USERNAME"
  HEADER_API_USER_EXTERNAL_ID ||= "HTTP_API_USER_EXTERNAL_ID"
  HEADER_API_USER_ID ||= "HTTP_API_USER_ID"
  USER_API_KEY ||= "HTTP_USER_API_KEY"
  USER_API_CLIENT_ID ||= "HTTP_USER_API_CLIENT_ID"
  API_KEY_ENV ||= "_DISCOURSE_API"
  USER_API_KEY_ENV ||= "_DISCOURSE_USER_API"
  TOKEN_COOKIE ||= ENV['DISCOURSE_TOKEN_COOKIE'] || "_t"
  PATH_INFO ||= "PATH_INFO"
  COOKIE_ATTEMPTS_PER_MIN ||= 10
  BAD_TOKEN ||= "_DISCOURSE_BAD_TOKEN"

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

    user_api_key = @env[USER_API_KEY]
    api_key = @env.blank? ? nil : @env[HEADER_API_KEY] || request[API_KEY]

    auth_token = request.cookies[TOKEN_COOKIE] unless user_api_key || api_key

    current_user = nil

    if auth_token && auth_token.length == 32
      limiter = RateLimiter.new(nil, "cookie_auth_#{request.ip}", COOKIE_ATTEMPTS_PER_MIN , 60)

      if limiter.can_perform?
        @user_token = UserAuthToken.lookup(auth_token,
                                           seen: true,
                                           user_agent: @env['HTTP_USER_AGENT'],
                                           path: @env['REQUEST_PATH'],
                                           client_ip: @request.ip)

        current_user = @user_token.try(:user)
      end

      if !current_user
        @env[BAD_TOKEN] = true
        begin
          limiter.performed!
        rescue RateLimiter::LimitExceeded
          raise Discourse::InvalidAccess.new(
            'Invalid Access',
            nil,
            delete_cookie: TOKEN_COOKIE
          )
        end
      end
    elsif @env['HTTP_DISCOURSE_LOGGED_IN']
      @env[BAD_TOKEN] = true
    end

    # possible we have an api call, impersonate
    if api_key
      current_user = lookup_api_user(api_key, request)
      raise Discourse::InvalidAccess.new(I18n.t('invalid_api_credentials'), nil, custom_message: "invalid_api_credentials") unless current_user
      raise Discourse::InvalidAccess if current_user.suspended? || !current_user.active
      @env[API_KEY_ENV] = true
      rate_limit_admin_api_requests(api_key)
    end

    # user api key handling
    if user_api_key

      limiter_min = RateLimiter.new(nil, "user_api_min_#{user_api_key}", GlobalSetting.max_user_api_reqs_per_minute, 60)
      limiter_day = RateLimiter.new(nil, "user_api_day_#{user_api_key}", GlobalSetting.max_user_api_reqs_per_day, 86400)

      unless limiter_day.can_perform?
        limiter_day.performed!
      end

      unless  limiter_min.can_perform?
        limiter_min.performed!
      end

      current_user = lookup_user_api_user_and_update_key(user_api_key, @env[USER_API_CLIENT_ID])
      raise Discourse::InvalidAccess unless current_user
      raise Discourse::InvalidAccess if current_user.suspended? || !current_user.active

      limiter_min.performed!
      limiter_day.performed!

      @env[USER_API_KEY_ENV] = true
    end

    # keep this rule here as a safeguard
    # under no conditions to suspended or inactive accounts get current_user
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

    @env[CURRENT_USER_KEY] = current_user
  end

  def refresh_session(user, session, cookies)
    # if user was not loaded, no point refreshing session
    # it could be an anonymous path, this would add cost
    return if is_api? || !@env.key?(CURRENT_USER_KEY)

    if !is_user_api? && @user_token && @user_token.user == user
      rotated_at = @user_token.rotated_at

      needs_rotation = @user_token.auth_token_seen ? rotated_at < UserAuthToken::ROTATE_TIME.ago : rotated_at < UserAuthToken::URGENT_ROTATE_TIME.ago

      if needs_rotation
        if @user_token.rotate!(user_agent: @env['HTTP_USER_AGENT'],
                               client_ip: @request.ip,
                               path: @env['REQUEST_PATH'])
          cookies[TOKEN_COOKIE] = cookie_hash(@user_token.unhashed_auth_token)
        end
      end
    end

    if !user && cookies.key?(TOKEN_COOKIE)
      cookies.delete(TOKEN_COOKIE)
    end
  end

  def log_on_user(user, session, cookies, opts = {})
    @user_token = UserAuthToken.generate!(
      user_id: user.id,
      user_agent: @env['HTTP_USER_AGENT'],
      path: @env['REQUEST_PATH'],
      client_ip: @request.ip,
      staff: user.staff?,
      impersonate: opts[:impersonate])

    cookies[TOKEN_COOKIE] = cookie_hash(@user_token.unhashed_auth_token)
    unstage_user(user)
    make_developer_admin(user)
    enable_bootstrap_mode(user)
    @env[CURRENT_USER_KEY] = user
  end

  def cookie_hash(unhashed_auth_token)
    hash = {
      value: unhashed_auth_token,
      httponly: true,
      expires: SiteSetting.maximum_session_age.hours.from_now,
      secure: SiteSetting.force_https
    }

    if SiteSetting.same_site_cookies != "Disabled"
      hash[:same_site] = SiteSetting.same_site_cookies
    end

    hash
  end

  def unstage_user(user)
    if user.staged
      user.unstage
      user.save
    end
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
    return if SiteSetting.bootstrap_mode_enabled

    if user.admin && user.last_seen_at.nil? && user.is_singular_admin?
      Jobs.enqueue(:enable_bootstrap_mode, user_id: user.id)
    end
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

    cookies.delete('authentication_data')
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
    return false if Discourse.pg_readonly_mode?

    api = !!(@env[API_KEY_ENV]) || !!(@env[USER_API_KEY_ENV])

    if @request.xhr? || api
      @env["HTTP_DISCOURSE_VISIBLE".freeze] == "true".freeze
    else
      true
    end
  end

  protected

  def lookup_user_api_user_and_update_key(user_api_key, client_id)
    if api_key = UserApiKey.where(key: user_api_key, revoked_at: nil).includes(:user).first
      unless api_key.allow?(@env)
        raise Discourse::InvalidAccess
      end

      api_key.update_columns(last_used_at: Time.zone.now)

      if client_id.present? && client_id != api_key.client_id

        # invalidate old dupe api key for client if needed
        UserApiKey
          .where(client_id: client_id, user_id: api_key.user_id)
          .where('id <> ?', api_key.id)
          .destroy_all

        api_key.update_columns(client_id: client_id)
      end

      api_key.user
    end
  end

  def lookup_api_user(api_key_value, request)
    if api_key = ApiKey.where(key: api_key_value).includes(:user).first
      api_username = header_api_key? ? @env[HEADER_API_USERNAME] : request[API_USERNAME]

      if api_key.allowed_ips.present? && !api_key.allowed_ips.any? { |ip| ip.include?(request.ip) }
        Rails.logger.warn("[Unauthorized API Access] username: #{api_username}, IP address: #{request.ip}")
        return nil
      end

      user =
        if api_key.user
          api_key.user if !api_username || (api_key.user.username_lower == api_username.downcase)
        elsif api_username
          User.find_by(username_lower: api_username.downcase)
        elsif user_id = header_api_key? ? @env[HEADER_API_USER_ID] : request["api_user_id"]
          User.find_by(id: user_id.to_i)
        elsif external_id = header_api_key? ? @env[HEADER_API_USER_EXTERNAL_ID] : request["api_user_external_id"]
          SingleSignOnRecord.find_by(external_id: external_id.to_s).try(:user)
        end

      if user
        api_key.update_columns(last_used_at: Time.zone.now)
      end

      user
    end
  end

  private

  def header_api_key?
    !!@env[HEADER_API_KEY]
  end

  def rate_limit_admin_api_requests(api_key)
    return if Rails.env == "profile"

    RateLimiter.new(
      nil,
      "admin_api_min_#{api_key}",
      GlobalSetting.max_admin_api_reqs_per_key_per_minute,
      60
    ).performed!
  end

end
