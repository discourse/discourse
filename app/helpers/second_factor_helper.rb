module SecondFactorHelper

  def self.totp(user)
    self.create_totp user
    ROTP::TOTP.new(user.user_second_factor.data, issuer: SiteSetting.title)
  end

  def self.create_totp(user)
    if !user.user_second_factor
      user.user_second_factor = UserSecondFactor.create(user_id: user.id, method: "totp", data: ROTP::Base32.random_base32)
    end
  end

  def self.provisioning_uri(user)
    self.totp(user).provisioning_uri(user.email)
  end

  def self.authenticate(user, token)
    totp = self.totp(user)
    last_used = 0
    if user.user_second_factor.last_used
      last_used = user.user_second_factor.last_used.to_i
    end
    authenticated = !token.blank? && totp.verify_with_drift_and_prior(token, 0, last_used)
    if authenticated
      user.user_second_factor.last_used = DateTime.now
      user.user_second_factor.save
    end
    return authenticated
  end

  def self.totp_enabled?(user)
    !!user.user_second_factor && user.user_second_factor.enabled?
  end
end
