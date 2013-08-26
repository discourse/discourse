class Auth::FacebookAuthenticator < Auth::Authenticator

  def name
    "facebook"
  end

  def after_authenticate(auth_token)

    result = Auth::Result.new

    session_info = parse_auth_token(auth_token)
    facebook_hash = session_info[:facebook]

    result.email = email = session_info[:email]
    result.name = name = facebook_hash[:name]

    result.extra_data = facebook_hash

    user_info = FacebookUserInfo.where(facebook_user_id: facebook_hash[:facebook_user_id]).first
    result.user = user_info.try(:user)

    if !result.user && result.user = User.where(email: Email.downcase(email)).first
      FacebookUserInfo.create({user_id: result.user.id}.merge(facebook_hash))
    end

    result
  end

  def after_create_account(user, auth)
    data = auth[:extra_data]
    FacebookUserInfo.create({user_id: user.id}.merge(data))
  end

  def register_middleware(omniauth)
    omniauth.provider :facebook,
           :setup => lambda { |env|
              strategy = env["omniauth.strategy"]
              strategy.options[:client_id] = SiteSetting.facebook_app_id
              strategy.options[:client_secret] = SiteSetting.facebook_app_secret
           },
           :scope => "email"
  end

  protected

  def parse_auth_token(auth_token)

    raw_info = auth_token["extra"]["raw_info"]
    email = auth_token["info"][:email]

    {
      facebook: {
        facebook_user_id: auth_token["uid"],
        link: raw_info["link"],
        username: raw_info["username"],
        first_name: raw_info["first_name"],
        last_name: raw_info["last_name"],
        email: email,
        gender: raw_info["gender"],
        name: raw_info["name"]
      },
      email: email,
      email_valid: true
    }

  end


end
