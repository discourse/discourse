class Auth::OpenIdAuthenticator < Auth::Authenticator

  def initialize(name, opts = {})
    @name = name
    @opts = opts
  end

  def name
    @name
  end

  def after_authenticate(auth_token)

    result = Auth::Result.new

    data = auth_token[:info]
    identity_url = auth_token[:extra][:identity_url]
    result.email = email = data[:email]

    # If the auth supplies a name / username, use those. Otherwise start with email.
    result.name = name = data[:name] || data[:email]
    result.username = username = data[:nickname] || data[:email]

    user_open_id = UserOpenId.find_by_url(identity_url)

    if !user_open_id && @opts[:trusted] && user = User.find_by_email(email)
      user_open_id = UserOpenId.create(url: identity_url , user_id: user.id, email: email, active: true)
    end

    result.user = user_open_id.try(:user)
    result.extra_data = {
      openid_url: identity_url
    }
    result.email_valid = @opts[:trusted]

    result
  end
end
