require_dependency "auth/current_user_provider"

class Auth::LpCurrentUserProvider < Auth::DefaultCurrentUserProvider

  # our current user, return nil if none is found
  def current_user
    return @env[CURRENT_USER_KEY] if @env.key?(CURRENT_USER_KEY)

    request = ActionDispatch::Request.new(@env)

    auth_token = request.cookies[TOKEN_COOKIE]

    current_user = nil

    if auth_token && auth_token.length == 32
      current_user = User.where(auth_token: auth_token).first
    end

    if current_user && current_user.suspended?
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
end
