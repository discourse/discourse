# frozen_string_literal: true

class ProblemCheck::RecaptchaConfiguration < ProblemCheck
  self.priority = "high"

  def call
    if SiteSetting.discourse_captcha_enabled &&
         SiteSetting.discourse_captcha_provider ==
           DiscourseCaptcha::CaptchaProvider::RECAPTCHA_V2 && !recaptcha_credentials_present?
      return problem
    end
    no_problem
  end

  private

  def recaptcha_credentials_present?
    SiteSetting.recaptcha_v2_site_key.present? && SiteSetting.recaptcha_v2_secret_key.present?
  end
end
