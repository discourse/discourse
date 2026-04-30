# frozen_string_literal: true

module DiscourseHcaptcha
  class RecaptchaProvider < CaptchaProvider
    CAPTCHA_VERIFICATION_URL = "https://www.google.com/recaptcha/api/siteverify"

    def fetch_captcha_token(cookies)
      fetch_token(:re_captcha_temp_id, "reCaptchaToken", cookies)
    end

    def captcha_verification_url
      CAPTCHA_VERIFICATION_URL
    end

    def send_captcha_verification(captcha_token)
      send_verification(captcha_token, CAPTCHA_VERIFICATION_URL, SiteSetting.recaptcha_secret_key)
    end
  end
end
