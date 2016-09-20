class Auth::FacebookAuthenticator < Auth::Authenticator

  def name
    "facebook"
  end

  def after_authenticate(auth_token)

    result = Auth::Result.new

    session_info = parse_auth_token(auth_token)
    facebook_hash = session_info[:facebook]

    result.email = email = session_info[:email]
    result.email_valid = !email.blank?
    result.name = facebook_hash[:name]

    result.extra_data = facebook_hash

    user_info = FacebookUserInfo.find_by(facebook_user_id: facebook_hash[:facebook_user_id])
    result.user = user_info.try(:user)

    if !result.user && !email.blank? && result.user = User.find_by_email(email)
      FacebookUserInfo.create({user_id: result.user.id}.merge(facebook_hash))
    end

    if user_info
      user_info.update_columns(facebook_hash)
    end

    user = result.user
    if user && (!user.user_avatar || user.user_avatar.custom_upload_id.nil?)
      if (avatar_url = facebook_hash[:avatar_url]).present?
        UserAvatar.import_url_for_user(avatar_url, user, override_gravatar: false)
      end
    end


    bio = facebook_hash[:about_me]
    location = facebook_hash[:location]
    website = facebook_hash[:website]

    if user && (bio || location || website)
      profile = user.user_profile

      profile.bio_raw = bio unless profile.bio_raw.present?
      profile.location = location unless profile.location.present?
      profile.website = website unless profile.website.present?
      profile.save
    end

    if email.blank?
      UserHistory.create(
        action: UserHistory.actions[:facebook_no_email],
        details: "name: #{facebook_hash[:name]}, facebook_user_id: #{facebook_hash[:facebook_user_id]}"
      )
    end

    result
  end

  def after_create_account(user, auth)
    data = auth[:extra_data]
    FacebookUserInfo.create({user_id: user.id}.merge(data))


    if (avatar_url = data[:avatar_url]).present?
      UserAvatar.import_url_for_user(avatar_url, user)
      user.save
    end

    bio = data[:about_me]
    location = data[:location]
    website = data[:website]

    if bio || location || website
      user.user_profile.bio_raw = bio
      user.user_profile.location = location
      user.user_profile.website = website
      user.user_profile.save
    end

    true
  end

  def register_middleware(omniauth)

    omniauth.provider :facebook,
           :setup => lambda { |env|
              strategy = env["omniauth.strategy"]
              strategy.options[:client_id] = SiteSetting.facebook_app_id
              strategy.options[:client_secret] = SiteSetting.facebook_app_secret
              strategy.options[:info_fields] = 'gender,email,name,bio,first_name,link,last_name,website,location'
              if SiteSetting.facebook_request_extra_profile_details
                strategy.options[:scope] = 'email,user_about_me,user_location,user_website'
              end
           },
           :scope => "email"
  end

  protected

  def parse_auth_token(auth_token)

    raw_info = auth_token["extra"]["raw_info"]
    info = auth_token["info"]

    email = auth_token["info"][:email]

    website = (info["urls"] && info["urls"]["Website"]) || nil

    {
      facebook: {
        facebook_user_id: auth_token["uid"],
        link: raw_info["link"],
        username: raw_info["username"],
        first_name: raw_info["first_name"],
        last_name: raw_info["last_name"],
        email: email,
        gender: raw_info["gender"],
        name: raw_info["name"],
        avatar_url: info["image"],
        location: info["location"],
        website: website,
        about_me: info["description"]
      },
      email: email,
      email_valid: true
    }

  end


end
