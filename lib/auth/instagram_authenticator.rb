class Auth::InstagramAuthenticator < Auth::Authenticator

  def name
    "instagram"
  end

  # TODO twitter provides all sorts of extra info, like website/bio etc.
  #  it may be worth considering pulling some of it in.
  def after_authenticate(auth_token)

    result = Auth::Result.new

    data = auth_token[:info]

    result.username = screen_name = data["nickname"]
    result.name = name = data["name"].slice!(0)
    instagram_user_id = auth_token["uid"]

    result.extra_data = {
      instagram_user_id: instagram_user_id,
      instagram_screen_name: screen_name
    }

    user_info = InstagramUserInfo.find_by(instagram_user_id: instagram_user_id)

    result.user = user_info.try(:user)

    result
  end

  def after_create_account(user, auth)
    data = auth[:extra_data]
    InstagramUserInfo.create(
      user_id: user.id,
      screen_name: data[:instagram_screen_name],
      instagram_user_id: data[:instagram_user_id]
    )
  end

  def register_middleware(omniauth)
    omniauth.provider :instagram,
           :setup => lambda { |env|
              strategy = env["omniauth.strategy"]
              strategy.options[:client_id] = SiteSetting.instagram_consumer_key
              strategy.options[:client_secret] = SiteSetting.instagram_consumer_secret
           }
  end

end
