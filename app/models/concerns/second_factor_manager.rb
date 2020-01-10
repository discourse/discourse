# frozen_string_literal: true

module SecondFactorManager
  TOTP_ALLOWED_DRIFT_SECONDS = 30

  extend ActiveSupport::Concern

  class SecondFactorAuthenticationResult
    attr_reader :ok, :error, :reason, :backup_enabled, :multiple_second_factor_methods

    def initialize(ok, params)
      @ok = ok
      @error = params[:error]
      @reason = params[:reason]
      @backup_enabled = params[:backup_enabled]
      @multiple_second_factor_methods = params[:multiple_second_factor_methods]
    end

    def to_h
      {
        error: error,
        reason: reason,
        backup_enabled: backup_enabled,
        multiple_second_factor_methods: multiple_second_factor_methods
      }
    end

    def ok?
      @ok
    end
  end

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

  def authenticate_second_factor(token, second_factor_method)
    second_factor_method = second_factor_method.to_i if !second_factor_method.is_a?(Integer)
    if second_factor_method == UserSecondFactor.methods[:totp]
      authenticate_totp(token)
    elsif second_factor_method == UserSecondFactor.methods[:backup_codes]
      authenticate_backup_code(token)
    end
  end

  def authenticate_second_factor_method(params, secure_session)
    ok_result = SecondFactorAuthenticationResult.new(true, {})
    return ok_result if !security_keys_enabled? && !totp_or_backup_codes_enabled?

    security_key_credential = params[:security_key_credential]
    totp_or_backup_code_token = params[:second_factor_token]
    second_factor_method = params[:second_factor_method]

    if only_security_keys_enabled?
      return authenticate_security_key(secure_session, security_key_credential) ? ok_result : invalid_security_key_result
    end

    if only_totp_or_backup_codes_enabled?
      return authenticate_second_factor(totp_or_backup_code_token, second_factor_method) ? ok_result : invalid_totp_result
    end

    # from this point on we can assume the user has both TOTP and
    # security keys enabled and we need to authenticate against
    # whichever one makes sense
    if totp_or_backup_code_token.blank?
      return authenticate_security_key(secure_session, security_key_credential) ? ok_result : invalid_security_key_result
    else
      return authenticate_second_factor(totp_or_backup_code_token, second_factor_method) ? ok_result : invalid_totp_result
    end

    ok_result
  rescue ::Webauthn::SecurityKeyError => err
    invalid_security_key_result(err.message)
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

  def invalid_totp_result
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

  def invalid_second_factor_authentication_result(error_message, reason)
    SecondFactorAuthenticationResult.new(
      false,
      error: error_message,
      reason: reason,
      backup_enabled: backup_codes_enabled?,
      multiple_second_factor_methods: has_multiple_second_factor_methods?
    )
  end

  def generate_backup_codes
    codes = []
    10.times do
      codes << SecureRandom.hex(8)
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
        stored_code = JSON.parse(code.data)["code_hash"]
        stored_salt = JSON.parse(code.data)["salt"]
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
