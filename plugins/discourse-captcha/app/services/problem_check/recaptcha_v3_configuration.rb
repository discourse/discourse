# frozen_string_literal: true

class ProblemCheck::RecaptchaV3Configuration < ProblemCheck
  self.priority = "high"

  def call
    if SiteSetting.discourse_captcha_enabled &&
         SiteSetting.discourse_captcha_provider ==
           DiscourseCaptcha::CaptchaProvider::RECAPTCHA_V3 && !recaptcha_v3_credentials_present?
      return problem
    end
    no_problem
  end

  private

  def recaptcha_v3_credentials_present?
    SiteSetting.recaptcha_v3_site_key.present? && SiteSetting.recaptcha_v3_secret_key.present?
  end
end
