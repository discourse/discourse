module SecondFactorManager
  extend ActiveSupport::Concern

  def totp
    self.create_totp
    ROTP::TOTP.new(self.user_second_factors.find_by_method(UserSecondFactor.methods[:totp]).data, issuer: SiteSetting.title)
  end

  def create_totp(opts = {})
    if !self.user_second_factors.find_by_method(UserSecondFactor.methods[:totp])
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

    if self.user_second_factors.find_by_method(UserSecondFactor.methods[:totp]).last_used
      last_used = self.user_second_factors.find_by_method(UserSecondFactor.methods[:totp]).last_used.to_i
    end

    authenticated = !token.blank? && totp.verify_with_drift_and_prior(token, 30, last_used)
    self.user_second_factors.find_by_method(UserSecondFactor.methods[:totp]).update!(last_used: DateTime.now) if authenticated
    !!authenticated
  end

  def totp_enabled?
    !!(self&.user_second_factors&.find_by_method(UserSecondFactor.methods[:totp])&.enabled?) &&
      !SiteSetting.enable_sso &&
      SiteSetting.enable_local_logins
  end

  def backup_codes_enabled?
    !!(self&.user_second_factors&.find_by_method(UserSecondFactor.methods[:backup_codes])&.enabled?) &&
      !SiteSetting.enable_sso &&
      SiteSetting.enable_local_logins
  end

  def create_backup_codes(opts = {})
    if !self.user_second_factors.backup_codes
      codes = []

      10.times do
        codes << SecureRandom.hex(4)
      end

      hashed_codes = codes.map do |code|
        hash_backup_code(code, self.salt)
      end

      UserSecondFactor.create!({
        user_id: self.id,
        data: hashed_codes,
        enabled: true,
        method: UserSecondFactor.methods[:backup_codes]
      }.merge(opts))

      codes
    end
  end

  def regenerate_backup_codes
    codes = []

    10.times do
      codes << SecureRandom.hex(4)
    end

    hashed_codes = codes.map do |code|
      hash_backup_code(code, self.salt)
    end

    self.user_second_factors.backup_codes.update(data: hashed_codes)

    codes
  end

  def authenticate_backup_code(backup_code)
    if !backup_code.blank?
      codes = self&.user_second_factors&.find_by_method(UserSecondFactor.methods[:backup_codes])&.data || []
      codes = eval(codes)

      backup_hash = hash_backup_code(backup_code, self.salt)
      codes.each do |code|
        next unless backup_hash == code

        codes.delete(backup_hash)
        self.user_second_factors.update(data: codes, method: UserSecondFactor.methods[:backup_codes])
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
