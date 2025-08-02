# frozen_string_literal: true

class ProblemCheck::HcaptchaConfiguration < ProblemCheck
  self.priority = "high"

  def call
    return problem if SiteSetting.discourse_hcaptcha_enabled && !hcaptcha_credentias_present?

    no_problem
  end

  private

  def hcaptcha_credentias_present?
    SiteSetting.hcaptcha_site_key.present? && SiteSetting.hcaptcha_secret_key.present?
  end
end
