class Auth::OpenIdAuthenticator < Auth::Authenticator

  attr_reader :name, :identifier

  def initialize(name, identifier, opts = {})
    @name = name
    @identifier = identifier
    @opts = opts
  end

  def after_authenticate(auth_token)
    result = Auth::Result.new

    data = auth_token[:info]
    identity_url = auth_token[:extra][:response].identity_url
    result.email = email = data[:email]

    raise Discourse::InvalidParameters.new(:email) if email.blank?

    # If the auth supplies a name / username, use those. Otherwise start with email.
    result.name = data[:name] || data[:email]
    result.username = data[:nickname] || data[:email]

    user_open_id = UserOpenId.find_by_url(identity_url)

    if !user_open_id && @opts[:trusted] && user = User.find_by_email(email)
      user_open_id = UserOpenId.create(url: identity_url , user_id: user.id, email: email, active: true)
    end

    result.user = user_open_id.try(:user)
    result.extra_data = {
      openid_url: identity_url,
      # note email may change by the time after_create_account runs
      email: email
    }

    result.email_valid = @opts[:trusted]

    result
  end

  def after_create_account(user, auth)
    data = auth[:extra_data]
    UserOpenId.create(
      user_id: user.id,
      url: data[:openid_url],
      email: data[:email],
      active: true
    )
  end


  def register_middleware(omniauth)
    omniauth.provider :open_id,
           :setup => lambda { |env|
              strategy = env["omniauth.strategy"]
              strategy.options[:store] = OpenID::Store::Redis.new($redis)
           },
           :name => name,
           :identifier => identifier,
           :require => "omniauth-openid"
  end
end
