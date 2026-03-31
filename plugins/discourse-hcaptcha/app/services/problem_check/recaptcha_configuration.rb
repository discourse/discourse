# frozen_string_literal: true

class ProblemCheck::RecaptchaConfiguration < ProblemCheck
  self.priority = "high"

  def call
    return problem if SiteSetting.discourse_recaptcha_enabled && !recaptcha_credentials_present?

    no_problem
  end

  private

  def recaptcha_credentials_present?
    SiteSetting.recaptcha_site_key.present? && SiteSetting.recaptcha_secret_key.present?
  end
end
