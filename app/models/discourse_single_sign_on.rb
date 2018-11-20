require_dependency 'single_sign_on'

class DiscourseSingleSignOn < SingleSignOn

  def self.sso_url
    SiteSetting.sso_url
  end

  def self.sso_secret
    SiteSetting.sso_secret
  end

  def self.generate_sso(return_path = "/")
    sso = new
    sso.nonce = SecureRandom.hex
    sso.register_nonce(return_path)
    sso.return_sso_url = Discourse.base_url + "/session/sso_login"
    sso
  end

  def self.generate_url(return_path = "/")
    generate_sso(return_path).to_url
  end

  def register_nonce(return_path)
    if nonce
      $redis.setex(nonce_key, NONCE_EXPIRY_TIME, return_path)
    end
  end

  def nonce_valid?
    nonce && $redis.get(nonce_key).present?
  end

  def return_path
    $redis.get(nonce_key) || "/"
  end

  def expire_nonce!
    if nonce
      $redis.del nonce_key
    end
  end

  def nonce_key
    "SSO_NONCE_#{nonce}"
  end

  def lookup_or_create_user(ip_address = nil)
    sso_record = SingleSignOnRecord.find_by(external_id: external_id)

    if sso_record && (user = sso_record.user)
      sso_record.last_payload = unsigned_payload
    else
      user = match_email_or_create_user(ip_address)
      sso_record = user.single_sign_on_record
    end

    # ensure it's not staged anymore
    user.unstage
    user.save

    change_external_attributes_and_override(sso_record, user)

    if sso_record && (user = sso_record.user) && !user.active && !require_activation
      user.active = true
      user.save!
      user.enqueue_welcome_message('welcome_user') unless suppress_welcome_message
      user.set_automatic_groups
    end

    custom_fields.each do |k, v|
      user.custom_fields[k] = v
    end

    user.ip_address = ip_address

    user.admin = admin unless admin.nil?
    user.moderator = moderator unless moderator.nil?

    user.title = title unless title.nil?

    # optionally save the user and sso_record if they have changed
    user.user_avatar.save! if user.user_avatar
    user.save!

    if bio && (user.user_profile.bio_raw.blank? || SiteSetting.sso_overrides_bio)
      user.user_profile.bio_raw = bio
      user.user_profile.save!
    end

    if website
      user.user_profile.website = website
      user.user_profile.save!
    end

    unless admin.nil? && moderator.nil?
      Group.refresh_automatic_groups!(:admins, :moderators, :staff)
    end

    sso_record.save!

    if sso_record.user
      apply_group_rules(sso_record.user)
    end

    sso_record && sso_record.user
  end

  private

  def synchronize_groups(user)
    names = (groups || "").split(",").map(&:downcase)
    ids = Group.where('LOWER(NAME) in (?) AND NOT automatic', names).pluck(:id)

    group_users = GroupUser
      .where('group_id IN (SELECT id FROM groups WHERE NOT automatic)')
      .where(user_id: user.id)

    delete_group_users = group_users
    if ids.length > 0
      delete_group_users = group_users.where('group_id NOT IN (?)', ids)
    end
    delete_group_users.destroy_all

    ids -= group_users.where('group_id IN (?)', ids).pluck(:group_id)

    ids.each do |group_id|
      GroupUser.create(group_id: group_id, user_id: user.id)
    end
  end

  def apply_group_rules(user)
    if SiteSetting.sso_overrides_groups
      synchronize_groups(user)
      return
    end

    if add_groups
      split = add_groups.split(",").map(&:downcase)
      if split.length > 0
        Group.where('LOWER(name) in (?) AND NOT automatic', split).pluck(:id).each do |id|
          unless GroupUser.where(group_id: id, user_id: user.id).exists?
            GroupUser.create(group_id: id, user_id: user.id)
          end
        end
      end
    end

    if remove_groups
      split = remove_groups.split(",").map(&:downcase)
      if split.length > 0
        GroupUser
          .where(user_id: user.id)
          .where('group_id IN (SELECT id FROM groups WHERE LOWER(name) in (?))', split)
          .destroy_all
      end
    end
  end

  def match_email_or_create_user(ip_address)
    # Use a mutex here to counter SSO requests that are sent at the same time w
    # the same email payload
    DistributedMutex.synchronize("discourse_single_sign_on_#{email}") do
      user = User.find_by_email(email) if !require_activation
      if !user
        try_name = name.presence
        try_username = username.presence

        user_params = {
          primary_email: UserEmail.new(email: email, primary: true),
          name: try_name || User.suggest_name(try_username || email),
          username: UserNameSuggester.suggest(try_username || try_name || email),
          ip_address: ip_address
        }

        if SiteSetting.allow_user_locale && locale && LocaleSiteSetting.valid_value?(locale)
          user_params[:locale] = locale
        end

        user = User.create!(user_params)

        if SiteSetting.verbose_sso_logging
          Rails.logger.warn("Verbose SSO log: New User (user_id: #{user.id}) Params: #{user_params} User Params: #{user.attributes} User Errors: #{user.errors.full_messages} Email: #{user.primary_email.attributes} Email Error: #{user.primary_email.errors.full_messages}")
        end
      end

      if user
        if sso_record = user.single_sign_on_record
          sso_record.last_payload = unsigned_payload
          sso_record.external_id = external_id
        else
          if avatar_url.present?
            Jobs.enqueue(:download_avatar_from_url,
              url: avatar_url,
              user_id: user.id,
              override_gravatar: SiteSetting.sso_overrides_avatar
            )
          end

          if profile_background_url.present?
            Jobs.enqueue(:download_profile_background_from_url,
              url: profile_background_url,
              user_id: user.id,
              is_card_background: false
            )
          end

          if card_background_url.present?
            Jobs.enqueue(:download_profile_background_from_url,
              url: card_background_url,
              user_id: user.id,
              is_card_background: true
            )
          end

          user.create_single_sign_on_record!(
            last_payload: unsigned_payload,
            external_id: external_id,
            external_username: username,
            external_email: email,
            external_name: name,
            external_avatar_url: avatar_url,
            external_profile_background_url: profile_background_url,
            external_card_background_url: card_background_url
          )
        end
      end

      user
    end
  end

  def change_external_attributes_and_override(sso_record, user)
    if SiteSetting.sso_overrides_email && user.email != Email.downcase(email)
      user.email = email
      user.active = false if require_activation
    end

    if SiteSetting.sso_overrides_username? && username.present?
      if user.username.downcase == username.downcase
        user.username = username # there may be a change of case
      elsif user.username != username
        user.username = UserNameSuggester.suggest(username || name || email, user.username)
      end
    end

    if SiteSetting.sso_overrides_name && user.name != name && name.present?
      user.name = name || User.suggest_name(username.blank? ? email : username)
    end

    if locale_force_update && SiteSetting.allow_user_locale && locale && LocaleSiteSetting.valid_value?(locale)
      user.locale = locale
    end

    avatar_missing = user.uploaded_avatar_id.nil? || !Upload.exists?(user.uploaded_avatar_id)

    if (avatar_missing || avatar_force_update || SiteSetting.sso_overrides_avatar) && avatar_url.present?
      avatar_changed = sso_record.external_avatar_url != avatar_url

      if avatar_force_update || avatar_changed || avatar_missing
        Jobs.enqueue(:download_avatar_from_url, url: avatar_url, user_id: user.id, override_gravatar: SiteSetting.sso_overrides_avatar)
      end
    end

    profile_background_missing = user.user_profile.profile_background.blank? || Upload.get_from_url(user.user_profile.profile_background).blank?
    if (profile_background_missing || SiteSetting.sso_overrides_profile_background) && profile_background_url.present?
      profile_background_changed = sso_record.external_profile_background_url != profile_background_url
      if profile_background_changed || profile_background_missing
        Jobs.enqueue(:download_profile_background_from_url,
            url: profile_background_url,
            user_id: user.id,
            is_card_background: false
        )
      end
    end

    card_background_missing = user.user_profile.card_background.blank? || Upload.get_from_url(user.user_profile.card_background).blank?
    if (card_background_missing || SiteSetting.sso_overrides_profile_background) && card_background_url.present?
      card_background_changed = sso_record.external_card_background_url != card_background_url
      if card_background_changed || card_background_missing
        Jobs.enqueue(:download_profile_background_from_url,
            url: card_background_url,
            user_id: user.id,
            is_card_background: true
        )
      end
    end

    # change external attributes for sso record
    sso_record.external_username = username
    sso_record.external_email = email
    sso_record.external_name = name
    sso_record.external_avatar_url = avatar_url
    sso_record.external_profile_background_url = profile_background_url
    sso_record.external_card_background_url = card_background_url
  end
end
