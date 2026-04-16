# frozen_string_literal: true

class ProblemCheck::HcaptchaConfiguration < ProblemCheck
  self.priority = "high"

  def call
    if SiteSetting.discourse_captcha_enabled && SiteSetting.discourse_hcaptcha_enabled &&
         !hcaptcha_credentials_present?
      return problem
    end

    no_problem
  end

  private

  def hcaptcha_credentials_present?
    SiteSetting.hcaptcha_site_key.present? && SiteSetting.hcaptcha_secret_key.present?
  end
end
