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
      twitter_email: result.email,
      twitter_user_id: twitter_user_id,
      twitter_screen_name: result.username,
      twitter_image: data["image"],
      twitter_description: data["description"],
      twitter_location: data["location"]
    }

    user_info = TwitterUserInfo.find_by(twitter_user_id: twitter_user_id)

    result.user = user_info.try(:user)
    if (!result.user) && result.email_valid && (result.user = User.find_by_email(result.email))
      TwitterUserInfo.create(
        user_id: result.user.id,
        screen_name: result.username,
        twitter_user_id: twitter_user_id,
        email: result.email
      )
    end

    retrieve_avatar(result.user, result.extra_data)
    retrieve_profile(result.user, result.extra_data)

    result
  end

  def after_create_account(user, auth)
    extra_data = auth[:extra_data]

    TwitterUserInfo.create(
      user_id: user.id,
      screen_name: extra_data[:twitter_screen_name],
      twitter_user_id: extra_data[:twitter_user_id],
      email: extra_data[:email]
    )

    retrieve_avatar(user, extra_data)
    retrieve_profile(user, extra_data)

    true
  end

  def register_middleware(omniauth)
    omniauth.provider :twitter,
           setup: lambda { |env|
             strategy = env["omniauth.strategy"]
              strategy.options[:consumer_key] = SiteSetting.twitter_consumer_key
              strategy.options[:consumer_secret] = SiteSetting.twitter_consumer_secret
           }
  end

  protected

  def retrieve_avatar(user, data)
    return unless user
    return if user.user_avatar.try(:custom_upload_id).present?

    if (avatar_url = data[:twitter_image]).present?
      url = avatar_url.sub("_normal", "")
      Jobs.enqueue(:download_avatar_from_url, url: url, user_id: user.id, override_gravatar: false)
    end
  end

  def retrieve_profile(user, data)
    return unless user

    bio = data[:twitter_description]
    location = data[:twitter_location]

    if bio || location
      profile = user.user_profile
      profile.bio_raw  = bio      unless profile.bio_raw.present?
      profile.location = location unless profile.location.present?
      profile.save
    end
  end

end
