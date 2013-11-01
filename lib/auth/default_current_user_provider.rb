require_dependency "auth/current_user_provider"

class Auth::DefaultCurrentUserProvider

  CURRENT_USER_KEY ||= "_DISCOURSE_CURRENT_USER"
  API_KEY ||= "_DISCOURSE_API"
  TOKEN_COOKIE ||= "_t"

  # do all current user initialization here
  def initialize(env)
    @env = env
    @request = Rack::Request.new(env)
  end

  # our current user, return nil if none is found
  def current_user
    return @env[CURRENT_USER_KEY] if @env.key?(CURRENT_USER_KEY)

    request = Rack::Request.new(@env)

    auth_token = request.cookies[TOKEN_COOKIE]

    current_user = nil

    if auth_token && auth_token.length == 32
      current_user = User.where(auth_token: auth_token).first
    end

    if current_user && current_user.is_banned?
      current_user = nil
    end

    if current_user
      current_user.update_last_seen!
      current_user.update_ip_address!(request.ip)
    end

    # possible we have an api call, impersonate
    unless current_user
      if api_key_value = request["api_key"]
        api_key = ApiKey.where(key: api_key_value).includes(:user).first
        if api_key.present?
          @env[API_KEY] = true
          api_username = request["api_username"]

          if api_key.user.present?
            raise Discourse::InvalidAccess.new if api_username && (api_key.user.username_lower != api_username.downcase)
            current_user = api_key.user
          elsif api_username
            current_user = User.where(username_lower: api_username.downcase).first
          end

        end
      end
    end

    @env[CURRENT_USER_KEY] = current_user
  end

  def log_on_user(user, session, cookies)
    unless user.auth_token && user.auth_token.length == 32
      user.auth_token = SecureRandom.hex(16)
      user.save!
    end
    cookies.permanent[TOKEN_COOKIE] = { value: user.auth_token, httponly: true }
    make_developer_admin(user)
    @env[CURRENT_USER_KEY] = user
  end

  def make_developer_admin(user)
    if  user.active? &&
        !user.admin &&
        Rails.configuration.respond_to?(:developer_emails) &&
        Rails.configuration.developer_emails.include?(user.email)
      user.update_column(:admin, true)
    end
  end

  def log_off_user(session, cookies)
    cookies[TOKEN_COOKIE] = nil
  end


  # api has special rights return true if api was detected
  def is_api?
    current_user
    @env[API_KEY]
  end

  def has_auth_cookie?
    request = Rack::Request.new(@env)
    cookie = request.cookies[TOKEN_COOKIE]
    !cookie.nil? && cookie.length == 32
  end
end
