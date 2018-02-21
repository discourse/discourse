module SecondFactorManager
  extend ActiveSupport::Concern

  def totp
    self.create_totp
    ROTP::TOTP.new(self.user_second_factor.data, issuer: SiteSetting.title)
  end

  def create_totp(opts = {})
    if !self.user_second_factor
      self.create_user_second_factor!({
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

    if self.user_second_factor.last_used
      last_used = self.user_second_factor.last_used.to_i
    end

    authenticated = !token.blank? && totp.verify_with_drift_and_prior(token, 0, last_used)
    self.user_second_factor.update!(last_used: DateTime.now) if authenticated
    !!authenticated
  end

  def totp_enabled?
    !!(self&.user_second_factor&.enabled?)
  end
end
