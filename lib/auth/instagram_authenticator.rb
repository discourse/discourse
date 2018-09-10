class Auth::InstagramAuthenticator < Auth::Authenticator

  def name
    "instagram"
  end

  def enabled?
    SiteSetting.enable_instagram_logins
  end

  def description_for_user(user)
    info = InstagramUserInfo.find_by(user_id: user.id)
    info&.screen_name || ""
  end

  def can_revoke?
    true
  end

  def revoke(user, skip_remote: false)
    info = InstagramUserInfo.find_by(user_id: user.id)
    raise Discourse::NotFound if info.nil?
    # Instagram does not have any way for us to revoke tokens on their end
    info.destroy!
    true
  end

  def can_connect_existing_user?
    true
  end

  def after_authenticate(auth_token, existing_account: nil)

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

    if existing_account && (user_info.nil? || existing_account.id != user_info.user_id)
      user_info.destroy! if user_info
      user_info = InstagramUserInfo.create!(
        user_id: existing_account.id,
        screen_name: screen_name,
        instagram_user_id: instagram_user_id
      )
    end

    result.user = user_info&.user

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
           setup: lambda { |env|
             strategy = env["omniauth.strategy"]
              strategy.options[:client_id] = SiteSetting.instagram_consumer_key
              strategy.options[:client_secret] = SiteSetting.instagram_consumer_secret
           }
  end

end
