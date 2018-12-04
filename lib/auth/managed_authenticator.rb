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
    result = Auth::Result.new

    # Store all the metadata for later, in case the `after_create_account` hook is used
    result.extra_data = {
      provider: auth_token[:provider],
      uid: auth_token[:uid],
      info: auth_token[:info],
      extra: auth_token[:extra],
      credentials: auth_token[:credentials]
    }

    # Build the Auth::Result object
    info = auth_token[:info]
    result.email = email = info[:email]
    result.name = name = "#{info[:first_name]} #{info[:last_name]}"
    result.username = info[:nickname]

    # Try and find an association for this account
    association = UserAssociatedAccount.find_by(provider_name: auth_token[:provider], provider_uid: auth_token[:uid])
    result.user = association&.user

    # Reconnecting to existing account
    if can_connect_existing_user? && existing_account && (association.nil? || existing_account.id != association.user_id)
      association.destroy! if association
      association = nil
      result.user = existing_account
    end

    # Matching an account by email
    if match_by_email && association.nil? && (user = User.find_by_email(email))
      UserAssociatedAccount.where(user: user, provider_name: auth_token[:provider]).destroy_all # Destroy existing associations for the new user
      result.user = user
    end

    # Add the association to the database if it doesn't already exist
    if association.nil? && result.user
      association = create_association!(result.extra_data.merge(user: result.user))
    end

    # Update all the metadata in the association:
    if association
      association.update!(
        info: auth_token[:info] || {},
        credentials: auth_token[:credentials] || {},
        extra: auth_token[:extra] || {}
      )
      retrieve_avatar(result.user, auth_token.dig(:info, :image))
    end

    result.email_valid = true if result.email

    result
  end

  def create_association!(hash)
    association = UserAssociatedAccount.create!(
      user: hash[:user],
      provider_name: hash[:provider],
      provider_uid: hash[:uid],
      info: hash[:info] || {},
      credentials: hash[:credentials] || {},
      extra: hash[:extra] || {}
    )
  end

  def after_create_account(user, auth)
    data = auth[:extra_data]
    create_association!(data.merge(user: user))
    retrieve_avatar(user, data.dig(:info, :image))
  end

  def retrieve_avatar(user, url)
    return unless user && url
    return if user.user_avatar.try(:custom_upload_id).present?
    Jobs.enqueue(:download_avatar_from_url, url: url, user_id: user.id, override_gravatar: false)
  end
end
