# frozen_string_literal: true

class DiscourseConnect < DiscourseConnectBase

  class BlankExternalId < StandardError; end
  class BannedExternalId < StandardError; end

  def self.sso_url
    SiteSetting.discourse_connect_url
  end

  def self.sso_secret
    SiteSetting.discourse_connect_secret
  end

  def self.generate_sso(return_path = "/", secure_session:)
    sso = new(secure_session: secure_session)
    sso.nonce = SecureRandom.hex
    sso.register_nonce(return_path)
    sso.return_sso_url = Discourse.base_url + "/session/sso_login"
    sso
  end

  def self.generate_url(return_path = "/", secure_session:)
    generate_sso(return_path, secure_session: secure_session).to_url
  end

  def initialize(secure_session:)
    @secure_session = secure_session
  end

  def register_nonce(return_path)
    if nonce
      if SiteSetting.discourse_connect_csrf_protection
        @secure_session.set(nonce_key, return_path, expires: DiscourseConnectBase.nonce_expiry_time)
      else
        Discourse.cache.write(nonce_key, return_path, expires_in: DiscourseConnectBase.nonce_expiry_time)
      end
    end
  end

  def nonce_valid?
    if SiteSetting.discourse_connect_csrf_protection
      nonce && @secure_session[nonce_key].present?
    else
      nonce && Discourse.cache.read(nonce_key).present?
    end
  end

  def nonce_error
    if Discourse.cache.read(used_nonce_key).present?
      "Nonce has already been used"
    elsif SiteSetting.discourse_connect_csrf_protection
      "Nonce is incorrect, was generated in a different browser session, or has expired"
    else
      "Nonce is incorrect, or has expired"
    end
  end

  def return_path
    if SiteSetting.discourse_connect_csrf_protection
      @secure_session[nonce_key] || "/"
    else
      Discourse.cache.read(nonce_key) || "/"
    end
  end

  def expire_nonce!
    if nonce
      if SiteSetting.discourse_connect_csrf_protection
        @secure_session[nonce_key] = nil
      else
        Discourse.cache.delete nonce_key
      end

      Discourse.cache.write(used_nonce_key, return_path, expires_in: DiscourseConnectBase.used_nonce_expiry_time)
    end
  end

  def nonce_key
    "SSO_NONCE_#{nonce}"
  end

  def used_nonce_key
    "USED_SSO_NONCE_#{nonce}"
  end

  BANNED_EXTERNAL_IDS = %w{none nil blank null}

  def lookup_or_create_user(ip_address = nil)

    # we don't want to ban 0 from being an external id
    external_id = self.external_id.to_s

    if external_id.blank?
      raise BlankExternalId
    end

    if BANNED_EXTERNAL_IDS.include?(external_id.downcase)
      raise BannedExternalId, external_id
    end

    # we protect here to ensure there is no situation where the same external id
    # concurrently attempts to create or update sso records
    #
    # we can get duplicate HTTP requests quite easily (client rapid refresh) and this path does stuff such
    # as updating groups for a users and so on that can happen even after the sso record and user is there
    DistributedMutex.synchronize("sso_lookup_or_create_user_#{external_id}") do
      lookup_or_create_user_unsafe(ip_address)
    end
  end

  private

  def lookup_or_create_user_unsafe(ip_address)
    sso_record = SingleSignOnRecord.find_by(external_id: external_id)

    if sso_record && (user = sso_record.user)
      sso_record.last_payload = unsigned_payload
    else
      user = match_email_or_create_user(ip_address)
      sso_record = user.single_sign_on_record
    end

    # ensure it's not staged anymore
    user.unstage!

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

    if @email_changed && user.active
      user.set_automatic_groups
    end

    # The user might require approval
    user.create_reviewable

    if bio && (user.user_profile.bio_raw.blank? || SiteSetting.discourse_connect_overrides_bio)
      user.user_profile.bio_raw = bio
      user.user_profile.save!
    end

    if website
      user.user_profile.website = website
      user.user_profile.save!
    end

    if location
      user.user_profile.location = location
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
    if SiteSetting.discourse_connect_overrides_groups
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
    # Use a mutex here to counter SSO requests that are sent at the same time with
    # the same email payload
    DistributedMutex.synchronize("discourse_single_sign_on_#{email}") do
      user = User.find_by_email(email) if !require_activation
      if !user
        user_params = {
          primary_email: UserEmail.new(email: email, primary: true),
          name: resolve_name,
          username: resolve_username,
          ip_address: ip_address
        }

        if SiteSetting.allow_user_locale && locale && LocaleSiteSetting.valid_value?(locale)
          user_params[:locale] = locale
        end

        user = User.create!(user_params)

        if SiteSetting.verbose_discourse_connect_logging
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
              override_gravatar: SiteSetting.discourse_connect_overrides_avatar
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
    @email_changed = false

    if SiteSetting.auth_overrides_email && user.email != Email.downcase(email)
      user.email = email
      user.active = false if require_activation
      @email_changed = true
    end

    if SiteSetting.auth_overrides_username? && username.present?
      UsernameChanger.override(user, username)
    end

    if SiteSetting.auth_overrides_name && user.name != name && name.present?
      user.name = name || User.suggest_name(username.blank? ? email : username)
    end

    if locale_force_update && SiteSetting.allow_user_locale && locale && LocaleSiteSetting.valid_value?(locale)
      user.locale = locale
    end

    avatar_missing = user.uploaded_avatar_id.nil? || !Upload.exists?(user.uploaded_avatar_id)

    if (avatar_missing || avatar_force_update || SiteSetting.discourse_connect_overrides_avatar) && avatar_url.present?
      avatar_changed = sso_record.external_avatar_url != avatar_url

      if avatar_force_update || avatar_changed || avatar_missing
        Jobs.enqueue(:download_avatar_from_url, url: avatar_url, user_id: user.id, override_gravatar: SiteSetting.discourse_connect_overrides_avatar)
      end
    end

    if profile_background_url.present?
      profile_background_missing = user.user_profile.profile_background_upload.blank? || Upload.get_from_url(user.user_profile.profile_background_upload.url).blank?

      if profile_background_missing || SiteSetting.discourse_connect_overrides_profile_background
        profile_background_changed = sso_record.external_profile_background_url != profile_background_url
        if profile_background_changed || profile_background_missing
          Jobs.enqueue(:download_profile_background_from_url,
              url: profile_background_url,
              user_id: user.id,
              is_card_background: false
          )
        end
      end
    end

    if card_background_url.present?
      card_background_missing = user.user_profile.card_background_upload.blank? || Upload.get_from_url(user.user_profile.card_background_upload.url).blank?
      if card_background_missing || SiteSetting.discourse_connect_overrides_card_background
        card_background_changed = sso_record.external_card_background_url != card_background_url
        if card_background_changed || card_background_missing
          Jobs.enqueue(:download_profile_background_from_url,
              url: card_background_url,
              user_id: user.id,
              is_card_background: true
          )
        end
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

  def resolve_username
    suggester_input = [username, name]
    suggester_input << email if SiteSetting.use_email_for_username_and_name_suggestions
    UserNameSuggester.suggest(*suggester_input)
  end

  def resolve_name
    name_suggester_input = username.presence
    if SiteSetting.use_email_for_username_and_name_suggestions
      name_suggester_input = name_suggester_input || email
    end

    name.presence || User.suggest_name(name_suggester_input)
  end
end
