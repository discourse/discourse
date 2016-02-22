class Auth::GoogleOAuth2Authenticator < Auth::Authenticator

  def name
    "google_oauth2"
  end

  def after_authenticate(auth_hash)
    session_info = parse_hash(auth_hash)
    google_hash = session_info[:google]

    result = Auth::Result.new
    result.email = session_info[:email]
    result.email_valid = session_info[:email_valid]
    result.name = session_info[:name]

    result.extra_data = google_hash

    user_info = GoogleUserInfo.find_by(google_user_id: google_hash[:google_user_id])
    result.user = user_info.try(:user)

    if !result.user && !result.email.blank? && result.user = User.find_by_email(result.email)
      GoogleUserInfo.create({user_id: result.user.id}.merge(google_hash))
    end

    result
  end

  def after_create_account(user, auth)
    data = auth[:extra_data]
    GoogleUserInfo.create({user_id: user.id}.merge(data))
  end

  def register_middleware(omniauth)
    # jwt encoding is causing auth to fail in quite a few conditions
    # skipping
    omniauth.provider :google_oauth2,
           :setup => lambda { |env|
              strategy = env["omniauth.strategy"]
              strategy.options[:client_id] = SiteSetting.google_oauth2_client_id
              strategy.options[:client_secret] = SiteSetting.google_oauth2_client_secret
           },
           skip_jwt: true
  end

  protected

  def parse_hash(hash)
    extra = hash[:extra][:raw_info]

    h = {}

    h[:email] = hash[:info][:email]
    h[:name] = hash[:info][:name]
    h[:email_valid] = hash[:extra][:raw_info][:email_verified]

    h[:google] = {
      google_user_id: hash[:uid] || extra[:sub],
      email: extra[:email],
      first_name: extra[:given_name],
      last_name: extra[:family_name],
      gender: extra[:gender],
      name: extra[:name],
      link: extra[:hd],
      profile_link: extra[:profile],
      picture: extra[:picture]
    }

    h
  end
end
