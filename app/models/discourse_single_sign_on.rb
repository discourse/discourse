require_dependency 'single_sign_on'

class DiscourseSingleSignOn < SingleSignOn

  def self.sso_url
    SiteSetting.sso_url
  end

  def self.sso_secret
    SiteSetting.sso_secret
  end

  def self.generate_url(return_path="/")
    sso = new
    sso.nonce = SecureRandom.hex
    sso.register_nonce(return_path)
    sso.return_sso_url = Discourse.base_url + "/session/sso_login"
    sso.to_url
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

  def lookup_or_create_user(ip_address=nil)
    sso_record = SingleSignOnRecord.find_by(external_id: external_id)

    if sso_record && user = sso_record.user
      sso_record.last_payload = unsigned_payload
    else
      user = match_email_or_create_user(ip_address)
      sso_record = user.single_sign_on_record
    end

    # if the user isn't new or it's attached to the SSO record we might be overriding username or email
    unless user.new_record?
      change_external_attributes_and_override(sso_record, user)
    end

    if sso_record && (user = sso_record.user) && !user.active && !require_activation
      user.active = true
      user.save!
      user.enqueue_welcome_message('welcome_user') unless suppress_welcome_message
    end

    custom_fields.each do |k,v|
      user.custom_fields[k] = v
    end

    user.ip_address = ip_address
    user.admin = admin unless admin.nil?
    user.moderator = moderator unless moderator.nil?

    # optionally save the user and sso_record if they have changed
    user.save!
    sso_record.save!

    sso_record && sso_record.user
  end

  private

  def match_email_or_create_user(ip_address)
    user = User.find_by_email(email)

    try_name = name.blank? ? nil : name
    try_username = username.blank? ? nil : username

    user_params = {
      email: email,
      name:  try_name || User.suggest_name(try_username || email),
      username: UserNameSuggester.suggest(try_username || try_name || email),
      ip_address: ip_address
    }

    if user || user = User.create!(user_params)
      if sso_record = user.single_sign_on_record
        sso_record.last_payload = unsigned_payload
        sso_record.external_id = external_id
      else
        user.create_single_sign_on_record(last_payload: unsigned_payload,
                                          external_id: external_id,
                                          external_username: username,
                                          external_email: email,
                                          external_name: name)
      end
    end

    user
  end

  def change_external_attributes_and_override(sso_record, user)
    if SiteSetting.sso_overrides_email && user.email != email
      user.email = email
    end

    if SiteSetting.sso_overrides_username && user.username != username && username.present?
      user.username = UserNameSuggester.suggest(username || name || email, user.username)
    end

    if SiteSetting.sso_overrides_name && user.name != name && name.present?
      user.name = name || User.suggest_name(username.blank? ? email : username)
    end

    if SiteSetting.sso_overrides_avatar && avatar_url.present? && (
      avatar_force_update ||
      sso_record.external_avatar_url != avatar_url)

      UserAvatar.import_url_for_user(avatar_url, user)
    end

    # change external attributes for sso record
    sso_record.external_username = username
    sso_record.external_email = email
    sso_record.external_name = name
    sso_record.external_avatar_url = avatar_url
  end
end
