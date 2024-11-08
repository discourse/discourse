# frozen_string_literal: true
require_relative "../route_matcher"

# You may have seen references to v0 and v1 of our auth cookie in the codebase
# and you're not sure how they differ, so here is an explanation:
#
# From the very early days of Discourse, the auth cookie (_t) consisted only of
# a 32 characters random string that Discourse used to identify/lookup the
# current user. We didn't include any metadata with the cookie or encrypt/sign
# it.
#
# That was v0 of the auth cookie until Nov 2021 when we merged a change that
# required us to store additional metadata with the cookie so we could get more
# information about current user early in the request lifecycle before we
# performed database lookup. We also started encrypting and signing the cookie
# to prevent tampering and obfuscate user information that we include in the
# cookie. This is v1 of our auth cookie and we still use it to this date.
#
# We still accept v0 of the auth cookie to keep users logged in, but upon
# cookie rotation (which happen every 10 minutes) they'll be switched over to
# the v1 format.
#
# We'll drop support for v0 after Discourse 2.9 is released.

class Auth::DefaultCurrentUserProvider
  CURRENT_USER_KEY = "_DISCOURSE_CURRENT_USER"
  USER_TOKEN_KEY = "_DISCOURSE_USER_TOKEN"
  API_KEY = "api_key"
  API_USERNAME = "api_username"
  HEADER_API_KEY = "HTTP_API_KEY"
  HEADER_API_USERNAME = "HTTP_API_USERNAME"
  HEADER_API_USER_EXTERNAL_ID = "HTTP_API_USER_EXTERNAL_ID"
  HEADER_API_USER_ID = "HTTP_API_USER_ID"
  PARAMETER_USER_API_KEY = "user_api_key"
  USER_API_KEY = "HTTP_USER_API_KEY"
  USER_API_CLIENT_ID = "HTTP_USER_API_CLIENT_ID"
  API_KEY_ENV = "_DISCOURSE_API"
  USER_API_KEY_ENV = "_DISCOURSE_USER_API"
  TOKEN_COOKIE = ENV["DISCOURSE_TOKEN_COOKIE"] || "_t"
  PATH_INFO = "PATH_INFO"
  COOKIE_ATTEMPTS_PER_MIN = 10
  BAD_TOKEN = "_DISCOURSE_BAD_TOKEN"
  DECRYPTED_AUTH_COOKIE = "_DISCOURSE_DECRYPTED_AUTH_COOKIE"

  TOKEN_SIZE = 32

  PARAMETER_API_PATTERNS = [
    RouteMatcher.new(
      methods: :get,
      actions: [
        "posts#latest",
        "posts#user_posts_feed",
        "groups#posts_feed",
        "groups#mentions_feed",
        "list#user_topics_feed",
        "list#category_feed",
        "topics#feed",
        "badges#show",
        "tags#tag_feed",
        "tags#show",
        *%i[latest unread new read posted bookmarks].map { |f| "list##{f}_feed" },
        *%i[all yearly quarterly monthly weekly daily].map { |p| "list#top_#{p}_feed" },
        *%i[latest unread new read posted bookmarks].map { |f| "tags#show_#{f}" },
      ],
      formats: :rss,
    ),
    RouteMatcher.new(methods: :get, actions: "users#bookmarks", formats: :ics),
    RouteMatcher.new(methods: :post, actions: "admin/email#handle_mail", formats: nil),
  ].freeze

  def self.find_v0_auth_cookie(request)
    cookie = request.cookies[TOKEN_COOKIE]

    cookie if cookie&.valid_encoding? && cookie.present? && cookie.size == TOKEN_SIZE
  end

  def self.find_v1_auth_cookie(env)
    return env[DECRYPTED_AUTH_COOKIE] if env.key?(DECRYPTED_AUTH_COOKIE)

    env[DECRYPTED_AUTH_COOKIE] = begin
      request = ActionDispatch::Request.new(env)
      cookie = request.cookies[TOKEN_COOKIE]

      # don't even initialize a cookie jar if we don't have a cookie at all
      if cookie&.valid_encoding? && cookie.present?
        request.cookie_jar.encrypted[TOKEN_COOKIE]&.with_indifferent_access
      end
    end
  end

  # do all current user initialization here
  def initialize(env)
    @env = env
    @request = Rack::Request.new(env)
    @user_token = env[USER_TOKEN_KEY]
  end

  # our current user, return nil if none is found
  def current_user
    return @env[CURRENT_USER_KEY] if @env.key?(CURRENT_USER_KEY)

    # bypass if we have the shared session header
    if shared_key = @env["HTTP_X_SHARED_SESSION_KEY"]
      uid = Discourse.redis.get("shared_session_key_#{shared_key}")
      user = nil
      user = User.find_by(id: uid.to_i) if uid
      @env[CURRENT_USER_KEY] = user
      return user
    end

    request = @request

    user_api_key = @env[USER_API_KEY]
    api_key = @env[HEADER_API_KEY]

    if !@env.blank? && request[PARAMETER_USER_API_KEY] && api_parameter_allowed?
      user_api_key ||= request[PARAMETER_USER_API_KEY]
    end

    api_key ||= request[API_KEY] if !@env.blank? && request[API_KEY] && api_parameter_allowed?

    auth_token = find_auth_token
    current_user = nil

    if auth_token
      limiter = RateLimiter.new(nil, "cookie_auth_#{request.ip}", COOKIE_ATTEMPTS_PER_MIN, 60)

      if limiter.can_perform?
        @env[USER_TOKEN_KEY] = @user_token =
          begin
            UserAuthToken.lookup(
              auth_token,
              seen: true,
              user_agent: @env["HTTP_USER_AGENT"],
              path: @env["REQUEST_PATH"],
              client_ip: @request.ip,
            )
          rescue ActiveRecord::ReadOnlyError
            nil
          end

        current_user = @user_token.try(:user)
        current_user.authenticated_with_oauth = @user_token.authenticated_with_oauth if current_user
      end

      if !current_user
        @env[BAD_TOKEN] = true
        begin
          limiter.performed!
        rescue RateLimiter::LimitExceeded
          raise Discourse::InvalidAccess.new("Invalid Access", nil, delete_cookie: TOKEN_COOKIE)
        end
      end
    elsif @env["HTTP_DISCOURSE_LOGGED_IN"]
      @env[BAD_TOKEN] = true
    end

    # possible we have an api call, impersonate
    if api_key
      current_user = lookup_api_user(api_key, request)
      if !current_user
        raise Discourse::InvalidAccess.new(
                I18n.t("invalid_api_credentials"),
                nil,
                custom_message: "invalid_api_credentials",
              )
      end
      raise Discourse::InvalidAccess if current_user.suspended? || !current_user.active

      if !Rails.env.profile?
        admin_api_key_limiter.performed!

        # Don't enforce the default per ip limits for authenticated admin api
        # requests
        (@env["DISCOURSE_RATE_LIMITERS"] || []).each(&:rollback!)
      end

      @env[API_KEY_ENV] = true
    end

    # user api key handling
    if user_api_key
      @hashed_user_api_key = ApiKey.hash_key(user_api_key)

      user_api_key_obj =
        UserApiKey
          .active
          .joins(:user)
          .where(key_hash: @hashed_user_api_key)
          .includes(:user, :scopes, :client)
          .first

      raise Discourse::InvalidAccess unless user_api_key_obj

      user_api_key_limiter_60_secs.performed!
      user_api_key_limiter_1_day.performed!

      user_api_key_obj.ensure_allowed!(@env)

      current_user = user_api_key_obj.user
      raise Discourse::InvalidAccess if current_user.suspended? || !current_user.active

      user_api_key_obj.update_last_used(@env[USER_API_CLIENT_ID]) if can_write?

      @env[USER_API_KEY_ENV] = true
    end

    # keep this rule here as a safeguard
    # under no conditions to suspended or inactive accounts get current_user
    current_user = nil if current_user && (current_user.suspended? || !current_user.active)

    if current_user && should_update_last_seen?
      ip = request.ip
      user_id = current_user.id
      old_ip = current_user.ip_address

      Scheduler::Defer.later "Updating Last Seen" do
        if User.should_update_last_seen?(user_id)
          if u = User.find_by(id: user_id)
            u.update_last_seen!(Time.zone.now, force: true)
          end
        end
        User.update_ip_address!(user_id, new_ip: ip, old_ip: old_ip)
      end
    end

    @env[CURRENT_USER_KEY] = current_user
  end

  def refresh_session(user, session, cookie_jar)
    # if user was not loaded, no point refreshing session
    # it could be an anonymous path, this would add cost
    return if is_api? || !@env.key?(CURRENT_USER_KEY)

    if !is_user_api? && @user_token && @user_token.user == user
      rotated_at = @user_token.rotated_at

      needs_rotation =
        (
          if @user_token.auth_token_seen
            rotated_at < UserAuthToken::ROTATE_TIME.ago
          else
            rotated_at < UserAuthToken::URGENT_ROTATE_TIME.ago
          end
        )

      if needs_rotation
        if @user_token.rotate!(
             user_agent: @env["HTTP_USER_AGENT"],
             client_ip: @request.ip,
             path: @env["REQUEST_PATH"],
           )
          set_auth_cookie!(@user_token.unhashed_auth_token, user, cookie_jar)
          DiscourseEvent.trigger(:user_session_refreshed, user)
        end
      end
    end

    cookie_jar.delete(TOKEN_COOKIE) if !user && cookie_jar.key?(TOKEN_COOKIE)
  end

  def log_on_user(user, session, cookie_jar, opts = {})
    @env[USER_TOKEN_KEY] = @user_token =
      UserAuthToken.generate!(
        user_id: user.id,
        user_agent: @env["HTTP_USER_AGENT"],
        path: @env["REQUEST_PATH"],
        client_ip: @request.ip,
        staff: user.staff?,
        impersonate: opts[:impersonate],
        authenticated_with_oauth: opts[:authenticated_with_oauth],
      )

    set_auth_cookie!(@user_token.unhashed_auth_token, user, cookie_jar)
    user.unstage!
    make_developer_admin(user)
    enable_bootstrap_mode(user)

    UserAuthToken.enforce_session_count_limit!(user.id)

    @env[CURRENT_USER_KEY] = user
  end

  def set_auth_cookie!(unhashed_auth_token, user, cookie_jar)
    data = {
      token: unhashed_auth_token,
      user_id: user.id,
      username: user.username,
      trust_level: user.trust_level,
      issued_at: Time.zone.now.to_i,
    }

    expires = SiteSetting.maximum_session_age.hours.from_now if SiteSetting.persistent_sessions

    same_site = SiteSetting.same_site_cookies if SiteSetting.same_site_cookies != "Disabled"

    cookie_jar.encrypted[TOKEN_COOKIE] = {
      value: data,
      httponly: true,
      secure: SiteSetting.force_https,
      expires: expires,
      same_site: same_site,
    }
  end

  # This is also used to set the first admin of the site via
  # the finish installation & register -> user account activation
  # for signup flow, since all admin emails are stored in
  # DISCOURSE_DEVELOPER_EMAILS for self-hosters.
  def make_developer_admin(user)
    if user.active? && !user.admin && Rails.configuration.respond_to?(:developer_emails) &&
         Rails.configuration.developer_emails.include?(user.email)
      user.admin = true
      user.save
      Group.refresh_automatic_groups!(:staff, :admins)
    end
  end

  def enable_bootstrap_mode(user)
    return if SiteSetting.bootstrap_mode_enabled

    if user.admin && user.last_seen_at.nil? && user.is_singular_admin?
      Jobs.enqueue(:enable_bootstrap_mode, user_id: user.id)
    end
  end

  def log_off_user(session, cookie_jar)
    user = current_user

    if SiteSetting.log_out_strict && user
      user.user_auth_tokens.destroy_all

      if user.admin && defined?(Rack::MiniProfiler)
        # clear the profiling cookie to keep stuff tidy
        cookie_jar.delete("__profilin")
      end

      user.logged_out
    elsif user && @user_token
      @user_token.destroy
      DiscourseEvent.trigger(:user_logged_out, user)
    end

    cookie_jar.delete("authentication_data")
    cookie_jar.delete(TOKEN_COOKIE)
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
    find_auth_token.present?
  end

  def should_update_last_seen?
    return false unless can_write?

    api = !!@env[API_KEY_ENV] || !!@env[USER_API_KEY_ENV]

    if @request.xhr? || api
      @env["HTTP_DISCOURSE_PRESENT"] == "true"
    else
      true
    end
  end

  protected

  def lookup_api_user(api_key_value, request)
    if api_key = ApiKey.active.with_key(api_key_value).includes(:user).first
      api_username = header_api_key? ? @env[HEADER_API_USERNAME] : request[API_USERNAME]

      return nil if !api_key.request_allowed?(@env)

      user =
        if api_key.user
          api_key.user if !api_username || (api_key.user.username_lower == api_username.downcase)
        elsif api_username
          User.find_by(username_lower: api_username.downcase)
        elsif user_id = header_api_key? ? @env[HEADER_API_USER_ID] : request["api_user_id"]
          User.find_by(id: user_id.to_i)
        elsif external_id =
              header_api_key? ? @env[HEADER_API_USER_EXTERNAL_ID] : request["api_user_external_id"]
          SingleSignOnRecord.find_by(external_id: external_id.to_s).try(:user)
        end

      if user && can_write?
        Scheduler::Defer.later "Updating api_key last_used" do
          api_key.update_last_used!
        end
      end

      user
    end
  end

  private

  def parameter_api_patterns
    PARAMETER_API_PATTERNS + DiscoursePluginRegistry.api_parameter_routes
  end

  # By default we only allow headers for sending API credentials
  # However, in some scenarios it is essential to send them via url parameters
  # so we need to add some exceptions
  def api_parameter_allowed?
    parameter_api_patterns.any? { |p| p.match?(env: @env) }
  end

  def header_api_key?
    !!@env[HEADER_API_KEY]
  end

  def can_write?
    @can_write ||= !Discourse.pg_readonly_mode?
  end

  def admin_api_key_limiter
    return @admin_api_key_limiter if @admin_api_key_limiter

    limit = GlobalSetting.max_admin_api_reqs_per_minute.to_i
    if GlobalSetting.respond_to?(:max_admin_api_reqs_per_key_per_minute)
      Discourse.deprecate(
        "DISCOURSE_MAX_ADMIN_API_REQS_PER_KEY_PER_MINUTE is deprecated. Please use DISCOURSE_MAX_ADMIN_API_REQS_PER_MINUTE",
        drop_from: "2.9.0",
      )
      limit = [GlobalSetting.max_admin_api_reqs_per_key_per_minute.to_i, limit].max
    end
    @admin_api_key_limiter =
      RateLimiter.new(nil, "admin_api_min", limit, 60, error_code: "admin_api_key_rate_limit")
  end

  def user_api_key_limiter_60_secs
    @user_api_key_limiter_60_secs ||=
      RateLimiter.new(
        nil,
        "user_api_min_#{@hashed_user_api_key}",
        GlobalSetting.max_user_api_reqs_per_minute,
        60,
        error_code: "user_api_key_limiter_60_secs",
      )
  end

  def user_api_key_limiter_1_day
    @user_api_key_limiter_1_day ||=
      RateLimiter.new(
        nil,
        "user_api_day_#{@hashed_user_api_key}",
        GlobalSetting.max_user_api_reqs_per_day,
        86_400,
        error_code: "user_api_key_limiter_1_day",
      )
  end

  def find_auth_token
    return @auth_token if defined?(@auth_token)

    @auth_token =
      begin
        if v0 = self.class.find_v0_auth_cookie(@request)
          v0
        elsif v1 = self.class.find_v1_auth_cookie(@env)
          v1[:token] if v1[:issued_at] >= SiteSetting.maximum_session_age.hours.ago.to_i
        end
      end
  end
end
