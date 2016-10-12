class Auth::TwitterAuthenticator < Auth::Authenticator

  def name
    "twitter"
  end

  def after_authenticate(auth_token)
    result = Auth::Result.new

    data = auth_token[:info]

    result.email = data["email"]
    result.email_valid = result.email.present?
    result.username = data["nickname"]
    result.name = data["name"]
    twitter_user_id = auth_token["uid"]

    result.extra_data = {
      twitter_user_id: twitter_user_id,
      twitter_screen_name: result.username
    }

    user_info = TwitterUserInfo.find_by(twitter_user_id: twitter_user_id)

    result.user = user_info.try(:user)
    if !result.user && result.email.present? && result.user = User.find_by_email(result.email)
      TwitterUserInfo.create(
        user_id: result.user.id,
        screen_name: result.username,
        twitter_user_id: twitter_user_id
      )
    end

    user = result.user
    if user && (!user.user_avatar || user.user_avatar.custom_upload_id.nil?)
      if (avatar_url = data["image"]).present?
        UserAvatar.import_url_for_user(avatar_url.sub("_normal", ""), user, override_gravatar: false)
      end
    end

    bio = data["description"]
    location = data["location"]

    if user && (bio || location)
      profile = user.user_profile
      profile.bio_raw  = bio      unless profile.bio_raw.present?
      profile.location = location unless profile.location.present?
      profile.save
    end

    result
  end

  def after_create_account(user, auth)
    data = auth[:extra_data]
    TwitterUserInfo.create(
      user_id: user.id,
      screen_name: data[:twitter_screen_name],
      twitter_user_id: data[:twitter_user_id]
    )
  end

  def register_middleware(omniauth)
    omniauth.provider :twitter,
           :setup => lambda { |env|
              strategy = env["omniauth.strategy"]
              strategy.options[:consumer_key] = SiteSetting.twitter_consumer_key
              strategy.options[:consumer_secret] = SiteSetting.twitter_consumer_secret
           }
  end

end
