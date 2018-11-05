class Auth::OpenIdAuthenticator < Auth::Authenticator

  attr_reader :name, :identifier

  def initialize(name, identifier, enabled_site_setting, opts = {})
    @name = name
    @identifier = identifier
    @enabled_site_setting = enabled_site_setting
    @opts = opts
  end

  def enabled?
    SiteSetting.send(@enabled_site_setting)
  end

  def description_for_user(user)
    info = UserOpenId.where("url LIKE ?", "#{@identifier}%").find_by(user_id: user.id)
    info&.email || ""
  end

  def can_revoke?
    true
  end

  def revoke(user, skip_remote: false)
    info = UserOpenId.where("url LIKE ?", "#{@identifier}%").find_by(user_id: user.id)
    raise Discourse::NotFound if info.nil?

    info.destroy!
    true
  end

  def can_connect_existing_user?
    true
  end

  def after_authenticate(auth_token, existing_account: nil)
    result = Auth::Result.new

    data = auth_token[:info]
    identity_url = auth_token[:extra][:response].identity_url
    result.email = email = data[:email]

    raise Discourse::InvalidParameters.new(:email) if email.blank?

    # If the auth supplies a name / username, use those. Otherwise start with email.
    result.name = data[:name] || data[:email]
    result.username = data[:nickname] || data[:email]

    user_open_id = UserOpenId.find_by_url(identity_url)

    if existing_account && (user_open_id.nil? || existing_account.id != user_open_id.user_id)
      user_open_id.destroy! if user_open_id
      user_open_id = UserOpenId.create!(url: identity_url , user_id: existing_account.id, email: email, active: true)
    end

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
         setup: lambda { |env|
           strategy = env["omniauth.strategy"]
           strategy.options[:store] = OpenID::Store::Redis.new($redis)

           # Add CSRF protection in addition to OpenID Specification
           def strategy.query_string
             session["omniauth.state"] = state = SecureRandom.hex(24)
             "?state=#{state}"
           end

           def strategy.callback_phase
             stored_state = session.delete("omniauth.state")
             provided_state = request.params["state"]
             return fail!(:invalid_credentials) unless provided_state == stored_state
             super
           end
         },
         name: name,
         identifier: identifier,
         require: "omniauth-openid"
  end
end
