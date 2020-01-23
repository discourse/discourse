# frozen_string_literal: true

module SecondFactorManager
  TOTP_ALLOWED_DRIFT_SECONDS = 30

  extend ActiveSupport::Concern

  SecondFactorAuthenticationResult = Struct.new(
    :ok, :error, :reason, :backup_enabled, :security_key_enabled, :totp_enabled, :multiple_second_factor_methods
  )

  def create_totp(opts = {})
    require_rotp
    UserSecondFactor.create!({
                               user_id: self.id,
                               method: UserSecondFactor.methods[:totp],
                               data: ROTP::Base32.random
                             }.merge(opts))
  end

  def get_totp_object(data)
    require_rotp
    ROTP::TOTP.new(data, issuer: SiteSetting.title)
  end

  def totp_provisioning_uri(data)
    get_totp_object(data).provisioning_uri(self.email)
  end

  def authenticate_totp(token)
    totps = self&.user_second_factors.totps
    authenticated = false
    totps.each do |totp|

      last_used = 0

      if totp.last_used
        last_used = totp.last_used.to_i
      end

      authenticated = !token.blank? && totp.totp_object.verify(
        token,
        drift_ahead: TOTP_ALLOWED_DRIFT_SECONDS,
        drift_behind: TOTP_ALLOWED_DRIFT_SECONDS,
        after: last_used
      )

      if authenticated
        totp.update!(last_used: DateTime.now)
        break
      end
    end
    !!authenticated
  end

  def totp_enabled?
    !SiteSetting.enable_sso &&
      SiteSetting.enable_local_logins &&
      self&.user_second_factors.totps.exists?
  end

  def backup_codes_enabled?
    !SiteSetting.enable_sso &&
      SiteSetting.enable_local_logins &&
      self&.user_second_factors.backup_codes.exists?
  end

  def security_keys_enabled?
    !SiteSetting.enable_sso &&
      SiteSetting.enable_local_logins &&
      self&.security_keys.where(factor_type: UserSecurityKey.factor_types[:second_factor], enabled: true).exists?
  end

  def has_any_second_factor_methods_enabled?
    totp_enabled? || security_keys_enabled?
  end

  def has_multiple_second_factor_methods?
    security_keys_enabled? && totp_or_backup_codes_enabled?
  end

  def totp_or_backup_codes_enabled?
    totp_enabled? || backup_codes_enabled?
  end

  def only_security_keys_enabled?
    security_keys_enabled? && !totp_or_backup_codes_enabled?
  end

  def only_totp_or_backup_codes_enabled?
    !security_keys_enabled? && totp_or_backup_codes_enabled?
  end

  def remaining_backup_codes
    self&.user_second_factors&.backup_codes&.count
  end

  def authenticate_second_factor(params, secure_session)
    ok_result = SecondFactorAuthenticationResult.new(true)
    return ok_result if !security_keys_enabled? && !totp_or_backup_codes_enabled?

    second_factor_token = params[:second_factor_token]
    second_factor_method = params[:second_factor_method]&.to_i

    if second_factor_method.blank? || UserSecondFactor.methods[second_factor_method].blank?
      return invalid_second_factor_method_result
    end

    if !valid_second_factor_method_for_user?(second_factor_method)
      return not_enabled_second_factor_method_result
    end

    case second_factor_method
    when UserSecondFactor.methods[:totp]
      return authenticate_totp(second_factor_token) ? ok_result : invalid_totp_or_backup_code_result
    when UserSecondFactor.methods[:backup_codes]
      return authenticate_backup_code(second_factor_token) ? ok_result : invalid_totp_or_backup_code_result
    when UserSecondFactor.methods[:security_key]
      return authenticate_security_key(secure_session, second_factor_token) ? ok_result : invalid_security_key_result
    end

    # if we have gotten down to this point without being
    # OK or invalid something has gone very weird.
    invalid_second_factor_method_result
  rescue ::Webauthn::SecurityKeyError => err
    invalid_security_key_result(err.message)
  end

  def valid_second_factor_method_for_user?(method)
    case method
    when UserSecondFactor.methods[:totp]
      return totp_enabled?
    when UserSecondFactor.methods[:backup_codes]
      return backup_codes_enabled?
    when UserSecondFactor.methods[:security_key]
      return security_keys_enabled?
    end
    false
  end

  def authenticate_security_key(secure_session, security_key_credential)
    ::Webauthn::SecurityKeyAuthenticationService.new(
      self,
      security_key_credential,
      challenge: Webauthn.challenge(self, secure_session),
      rp_id: Webauthn.rp_id(self, secure_session),
      origin: Discourse.base_url
    ).authenticate_security_key
  end

  def invalid_totp_or_backup_code_result
    invalid_second_factor_authentication_result(
      I18n.t("login.invalid_second_factor_code"),
      "invalid_second_factor"
    )
  end

  def invalid_security_key_result(error_message = nil)
    invalid_second_factor_authentication_result(
      error_message || I18n.t("login.invalid_security_key"),
      "invalid_security_key"
    )
  end

  def invalid_second_factor_method_result
    invalid_second_factor_authentication_result(
      I18n.t("login.invalid_second_factor_method"),
      "invalid_second_factor_method"
    )
  end

  def not_enabled_second_factor_method_result
    invalid_second_factor_authentication_result(
      I18n.t("login.not_enabled_second_factor_method"),
      "not_enabled_second_factor_method"
    )
  end

  def invalid_second_factor_authentication_result(error_message, reason)
    SecondFactorAuthenticationResult.new(
      false,
      error_message,
      reason,
      backup_codes_enabled?,
      security_keys_enabled?,
      totp_enabled?,
      has_multiple_second_factor_methods?
    )
  end

  def generate_backup_codes
    codes = []
    10.times do
      codes << SecureRandom.hex(16)
    end

    codes_json = codes.map do |code|
      salt = SecureRandom.hex(16)
      { salt: salt,
        code_hash: hash_backup_code(code, salt)
      }
    end

    if self.user_second_factors.backup_codes.empty?
      create_backup_codes(codes_json)
    else
      self.user_second_factors.where(method: UserSecondFactor.methods[:backup_codes]).destroy_all
      create_backup_codes(codes_json)
    end

    codes
  end

  def create_backup_codes(codes)
    codes.each do |code|
      UserSecondFactor.create!(
        user_id: self.id,
        data: code.to_json,
        enabled: true,
        method: UserSecondFactor.methods[:backup_codes]
      )
    end
  end

  def authenticate_backup_code(backup_code)
    if !backup_code.blank?
      codes = self&.user_second_factors&.backup_codes

      codes.each do |code|
        parsed_data = JSON.parse(code.data)
        stored_code = parsed_data["code_hash"]
        stored_salt = parsed_data["salt"]
        backup_hash = hash_backup_code(backup_code, stored_salt)
        next unless backup_hash == stored_code

        code.update(enabled: false, last_used: DateTime.now)
        return true
      end
      false
    end
    false
  end

  def hash_backup_code(code, salt)
    Pbkdf2.hash_password(code, salt, Rails.configuration.pbkdf2_iterations, Rails.configuration.pbkdf2_algorithm)
  end

  def require_rotp
    require 'rotp' if !defined? ROTP
  end
end
