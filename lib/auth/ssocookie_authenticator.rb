class Auth::SsoCookieAuthenticator < Auth::Authenticator

  def name
    "ssocookie"
  end

  def after_authenticate(auth_token)
    result = Auth::Result.new

    data = auth_token[:info]
    user_id = data["account_key"]

    result.username = screen_name = data["nickname"]
    result.email = email = "#{user_id}@udacityu.appspot.com"

    result.extra_data = {
      ssocookie_user_id: user_id,
      ssocookie_email: email,
    }

    user_info = SsoCookieUserInfo.where(sso_id: user_id).first

    if user_info
      user = user_info.user
    end

    result.user = user
    result.email_valid = true

    result
  end

  def after_create_account(user, auth)
    data = auth[:extra_data]
    SsoCookieUserInfo.create(
      user_id: user.id,
      sso_id: data[:ssocookie_user_id],
    )
    user.email = data[:ssocookie_email]
    user.toggle(:active)
    user.save
  end


  def register_middleware(omniauth)
    omniauth.provider :ssocookie,
           :setup => lambda { |env|
              strategy = env["omniauth.strategy"]
              strategy.options[:cookie_name] = SiteSetting.sso_cookie_name
              strategy.options[:encryption_key] = SiteSetting.sso_encryption_key
              strategy.options[:hmac_key] = SiteSetting.sso_hmac_key
              strategy.options[:login_url] = SiteSetting.sso_login_url
           }
  end
end
