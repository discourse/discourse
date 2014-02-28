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


  def lookup_or_create_user
    sso_record = SingleSignOnRecord.where(external_id: external_id).first
    if sso_record && sso_record.user
      sso_record.last_payload = unsigned_payload
      
      if SiteSetting.sso_overrides_email
        # set the user's email to whatever came in the payload
        if email
          sso_record.user.email = email
        end
      end
      
      # the user's external username has changed
      if SiteSetting.sso_overrides_username && username != sso_record.external_username
        # run it through the UserNameSuggester to override it
        sso_record.user.username = UserNameSuggester.suggest(username || name || email)  
        sso_record.external_username = username
      end
      
      if sso_record.user.changed?
        sso_record.user.save
      end
      
      sso_record.save
    else
      user = User.where(email: Email.downcase(email)).first

      user_params = {
          email: email,
          name:  User.suggest_name(name || username || email),
          username: UserNameSuggester.suggest(username || name || email),
      }

      if user || user = User.create(user_params)
        if sso_record = user.single_sign_on_record
          sso_record.last_payload = unsigned_payload
          sso_record.external_id = external_id
          sso_record.external_username = external_username
          sso_record.save!
        else
          sso_record = user.create_single_sign_on_record(last_payload: unsigned_payload,
                                            external_id: external_id,
                                            external_username: username)
        end
      end
    end

    if sso_record && (user = sso_record.user) && !user.active
      user.active = true
      user.save
      user.enqueue_welcome_message('welcome_user')
    end

    sso_record && sso_record.user
  end
end

