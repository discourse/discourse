class Auth::ManagedAuthenticator < Auth::Authenticator
  def description_for_user(user)
    info = UserAssociatedAccount.find_by(provider_name: name, user_id: user.id)&.info
    return "" if info.nil?
    info["email"] || info["nickname"] || info["name"] || ""
  end

  # These three methods are designed to be overriden by child classes
  def match_by_email
    true
  end

  def can_revoke?
    true
  end

  def can_connect_existing_user?
    true
  end

  def revoke(user, skip_remote: false)
    association = UserAssociatedAccount.find_by(provider_name: name, user_id: user.id)
    raise Discourse::NotFound if association.nil?
    association.destroy!
    true
  end

  def after_authenticate(auth_token, existing_account: nil)
    # Try and find an association for this account
    association = UserAssociatedAccount.find_or_initialize_by(provider_name: auth_token[:provider], provider_uid: auth_token[:uid])

    # Reconnecting to existing account
    if can_connect_existing_user? && existing_account && (association.user.nil? || existing_account.id != association.user_id)
      association.user = existing_account
    end

    # Matching an account by email
    if match_by_email && association.user.nil? && (user = User.find_by_email(auth_token.dig(:info, :email)))
      UserAssociatedAccount.where(user: user, provider_name: auth_token[:provider]).destroy_all # Destroy existing associations for the new user
      association.user = user
    end

    # Update all the metadata in the association:
    association.info = auth_token[:info] || {}
    association.credentials = auth_token[:credentials] || {}
    association.extra = auth_token[:extra] || {}

    # Save to the DB. Do this even if we don't have a user - it might be linked up later in after_create_account
    association.save!

    # Update avatar/profile
    retrieve_avatar(association.user, association.info["image"])
    retrieve_profile(association.user, association.info)

    # Build the Auth::Result object
    result = Auth::Result.new
    info = auth_token[:info]
    result.email = info[:email]
    result.name = "#{info[:first_name]} #{info[:last_name]}"
    result.username = info[:nickname]
    result.email_valid = true if result.email
    result.extra_data = {
      provider: auth_token[:provider],
      uid: auth_token[:uid]
    }
    result.user = association.user

    result
  end

  def after_create_account(user, auth)
    auth_token = auth[:extra_data]
    association = UserAssociatedAccount.find_or_initialize_by(provider_name: auth_token[:provider], provider_uid: auth_token[:uid])
    association.user = user
    association.save!

    retrieve_avatar(user, association.info["image"])
    retrieve_profile(user, association.info)
  end

  def retrieve_avatar(user, url)
    return unless user && url
    return if user.user_avatar.try(:custom_upload_id).present?
    Jobs.enqueue(:download_avatar_from_url, url: url, user_id: user.id, override_gravatar: false)
  end

  def retrieve_profile(user, info)
    return unless user

    bio = info["description"]
    location = info["location"]

    if bio || location
      profile = user.user_profile
      profile.bio_raw  = bio      unless profile.bio_raw.present?
      profile.location = location unless profile.location.present?
      profile.save
    end
  end
end
