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
    user.staged = false

    # if the user isn't new or it's attached to the SSO record we might be overriding username or email
    unless user.new_record?
      change_external_attributes_and_override(sso_record, user)
    end

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

  def apply_group_rules(user)
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
    unless user = User.find_by_email(email)
      try_name = name.presence
      try_username = username.presence

      user_params = {
        email: email,
        name: try_name || User.suggest_name(try_username || email),
        username: UserNameSuggester.suggest(try_username || try_name || email),
        ip_address: ip_address
      }

      user = User.create!(user_params)
    end

    if user
      if sso_record = user.single_sign_on_record
        sso_record.last_payload = unsigned_payload
        sso_record.external_id = external_id
      else
        Jobs.enqueue(:download_avatar_from_url, url: avatar_url, user_id: user.id, override_gravatar: SiteSetting.sso_overrides_avatar) if avatar_url.present?
        user.create_single_sign_on_record(
          last_payload: unsigned_payload,
          external_id: external_id,
          external_username: username,
          external_email: email,
          external_name: name,
          external_avatar_url: avatar_url
        )
      end
    end

    user
  end

  def change_external_attributes_and_override(sso_record, user)
    if SiteSetting.sso_overrides_email && user.email != email
      user.email = email
      user.active = false if require_activation
    end

    if SiteSetting.sso_overrides_username && user.username != username && username.present?
      user.username = UserNameSuggester.suggest(username || name || email, user.username)
    end

    if SiteSetting.sso_overrides_name && user.name != name && name.present?
      user.name = name || User.suggest_name(username.blank? ? email : username)
    end

    avatar_missing = user.uploaded_avatar_id.nil? || !Upload.exists?(user.uploaded_avatar_id)

    if (avatar_missing || avatar_force_update || SiteSetting.sso_overrides_avatar) && avatar_url.present?
      avatar_changed = sso_record.external_avatar_url != avatar_url

      if avatar_force_update || avatar_changed || avatar_missing
        Jobs.enqueue(:download_avatar_from_url, url: avatar_url, user_id: user.id, override_gravatar: SiteSetting.sso_overrides_avatar)
      end
    end

    # change external attributes for sso record
    sso_record.external_username = username
    sso_record.external_email = email
    sso_record.external_name = name
    sso_record.external_avatar_url = avatar_url
  end
end
