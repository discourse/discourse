# frozen_string_literal: true

class Auth::ManagedAuthenticator < Auth::Authenticator
  def is_managed?
    # Tells core that it can safely assume this authenticator
    # uses UserAssociatedAccount
    true
  end

  def description_for_user(user)
    associated_account = UserAssociatedAccount.find_by(provider_name: name, user_id: user.id)
    return "" if associated_account.nil?
    description_for_auth_hash(associated_account) || I18n.t("associated_accounts.connected")
  end

  def description_for_auth_hash(auth_token)
    return if auth_token&.info.nil?
    info = auth_token.info
    info["email"] || info["nickname"] || info["name"]
  end

  # These three methods are designed to be overridden by child classes
  def match_by_email
    true
  end

  # Depending on the authenticator, this could be insecure, so it's disabled by default
  def match_by_username
    false
  end

  def primary_email_verified?(auth_token)
    # Omniauth providers should only provide verified emails in the :info hash.
    # This method allows additional checks to be added
    false
  end

  def can_revoke?
    true
  end

  def can_connect_existing_user?
    true
  end

  def always_update_user_email?
    false
  end

  def revoke(user, skip_remote: false)
    association = UserAssociatedAccount.find_by(provider_name: name, user_id: user.id)
    raise Discourse::NotFound if association.nil?
    association.destroy!
    true
  end

  def after_authenticate(auth_token, existing_account: nil)
    # Try and find an association for this account
    association =
      UserAssociatedAccount.find_or_initialize_by(
        provider_name: auth_token[:provider],
        provider_uid: auth_token[:uid],
      )

    # Reconnecting to existing account
    if can_connect_existing_user? && existing_account &&
         (association.user.nil? || existing_account.id != association.user_id)
      association.user = existing_account
    end

    # Matching an account by email
    if match_by_email && association.user.nil? && (user = find_user_by_email(auth_token))
      UserAssociatedAccount.where(user: user, provider_name: auth_token[:provider]).destroy_all # Destroy existing associations for the new user
      association.user = user
    end

    # Matching an account by username
    if match_by_username && association.user.nil? && SiteSetting.username_change_period.zero? &&
         (user = find_user_by_username(auth_token))
      UserAssociatedAccount.where(user: user, provider_name: auth_token[:provider]).destroy_all # Destroy existing associations for the new user
      association.user = user
    end

    # Update all the metadata in the association:
    association.info = auth_token[:info] || {}
    association.credentials = auth_token[:credentials] || {}
    association.extra = auth_token[:extra] || {}

    association.last_used = Time.zone.now

    # Save to the DB. Do this even if we don't have a user - it might be linked up later in after_create_account
    association.save!

    # Update avatar/profile
    retrieve_avatar(association.user, association.info["image"])
    retrieve_profile(association.user, association.info)

    # Build the Auth::Result object
    info = auth_token[:info]
    result = Auth::Result.new
    result.email = info[:email]
    result.name = "#{info[:first_name]} #{info[:last_name]}".presence || info[:name]
    # Some IDPs send the email address in the name parameter (e.g. Auth0 with default configuration)
    # We add some generic protection here, so that users don't accidently make their email addresses public
    result.name = nil if result.name.present? && result.name == result.email
    result.username = info[:nickname]
    result.email_valid = primary_email_verified?(auth_token) if result.email.present?
    result.overrides_email = always_update_user_email?
    result.extra_data = { provider: auth_token[:provider], uid: auth_token[:uid] }
    result.user = association.user

    result
  end

  def after_create_account(user, auth_result)
    auth_token = auth_result[:extra_data]
    association =
      UserAssociatedAccount.find_or_initialize_by(
        provider_name: auth_token[:provider],
        provider_uid: auth_token[:uid],
      )
    association.user = user
    association.save!

    retrieve_avatar(user, association.info["image"])
    retrieve_profile(user, association.info)

    auth_result.apply_associated_attributes!
  end

  def find_user_by_email(auth_token)
    email = auth_token.dig(:info, :email)
    User.find_by_email(email) if email && primary_email_verified?(auth_token)
  end

  def find_user_by_username(auth_token)
    username = auth_token.dig(:info, :nickname)
    User.find_by_username(username) if username
  end

  def retrieve_avatar(user, url)
    return unless user && url.present?
    return if user.user_avatar.try(:custom_upload_id).present? && !SiteSetting.auth_overrides_avatar
    Jobs.enqueue(:download_avatar_from_url, url: url, user_id: user.id, override_gravatar: false)
  end

  def retrieve_profile(user, info)
    return unless user

    bio = info["description"]
    location = info["location"]

    if bio || location
      profile = user.user_profile
      profile.bio_raw = bio if profile.bio_raw.blank?
      profile.location = location if profile.location.blank?
      profile.save
    end
  end
end
