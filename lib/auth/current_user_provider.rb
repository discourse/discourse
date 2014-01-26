module Auth; end
class Auth::CurrentUserProvider

  API_KEY ||= "_DISCOURSE_API"
  CURRENT_USER_KEY ||= "_DISCOURSE_CURRENT_USER"

  # do all current user initialization here
  def initialize(env)
    @env = env
    @request = Rack::Request.new(env)
  end

  # Wrapper around the current_user function to handle memoization, suspending
  # users, updating last seen and IP address, and detecting API calls.
  def current_user_wrapper
    return @env[CURRENT_USER_KEY] if @env.key?(CURRENT_USER_KEY)

    user = current_user

    if user && user.suspended?
      user = nil
    end

    if user
      user.update_last_seen!
      user.update_ip_address!(@request.ip)
    end

    # possible we have an api call, impersonate
    unless user
      if api_key_value = @request["api_key"]
        api_key = ApiKey.where(key: api_key_value).includes(:user).first
        if api_key.present?
          @env[API_KEY] = true
          api_username = @request["api_username"]

          if api_key.user.present?
            raise Discourse::InvalidAccess.new if api_username && (api_key.user.username_lower != api_username.downcase)
            user = api_key.user
          elsif api_username
            user = User.where(username_lower: api_username.downcase).first
          end

        end
      end
    end

    @env[CURRENT_USER_KEY] = user
  end

  # our current user, return nil if none is found
  def current_user
    raise NotImplementedError
  end

  # log on a user and set cookies and session etc.
  def log_on_user(user,session,cookies)
    raise NotImplementedError
  end

  # api has special rights return true if api was detected
  def is_api?
    current_user_wrapper
    @env[API_KEY]
  end

  # we may need to know very early on in the middleware if an auth token
  # exists, to optimise caching
  def has_auth_cookie?
    raise NotImplementedError
  end

  def log_off_user(session, cookies)
    raise NotImplementedError
  end
end
