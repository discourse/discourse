module SecondFactorManager
  extend ActiveSupport::Concern

  def totp
    self.create_totp
    ROTP::TOTP.new(self.user_second_factors.totp.data, issuer: SiteSetting.title)
  end

  def create_totp(opts = {})
    if !self.user_second_factors.totp
      UserSecondFactor.create!({
        user_id: self.id,
        method: UserSecondFactor.methods[:totp],
        data: ROTP::Base32.random_base32
      }.merge(opts))
    end
  end

  def totp_provisioning_uri
    self.totp.provisioning_uri(self.email)
  end

  def authenticate_totp(token)
    totp = self.totp
    last_used = 0

    if self.user_second_factors.totp.last_used
      last_used = self.user_second_factors.totp.last_used.to_i
    end

    authenticated = !token.blank? && totp.verify_with_drift_and_prior(token, 30, last_used)
    self.user_second_factors.totp.update!(last_used: DateTime.now) if authenticated
    !!authenticated
  end

  def totp_enabled?
    !!(self&.user_second_factors&.totp&.enabled?) &&
      !SiteSetting.enable_sso &&
      SiteSetting.enable_local_logins
  end

  def backup_codes_enabled?
    !!(self&.user_second_factors&.backup_codes&.present?) &&
      !SiteSetting.enable_sso &&
      SiteSetting.enable_local_logins
  end

  def remaining_backup_codes
    self&.user_second_factors&.backup_codes&.count
  end

  def authenticate_second_factor(token, second_factor_method)
    if second_factor_method == UserSecondFactor.methods[:totp]
      authenticate_totp(token)
    elsif second_factor_method == UserSecondFactor.methods[:backup_codes]
      authenticate_backup_code(token)
    end
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
end
