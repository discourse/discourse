# frozen_string_literal: true

module DiscourseCaptcha
  class RecaptchaProvider < CaptchaProvider
    CAPTCHA_VERIFICATION_URL = "https://www.google.com/recaptcha/api/siteverify"

    def fetch_captcha_token(server_session)
      token = server_session["recaptcha_token"]
      server_session.delete("recaptcha_token")
      token
    end

    def captcha_verification_url
      CAPTCHA_VERIFICATION_URL
    end

    def send_captcha_verification(captcha_token)
      send_verification(captcha_token, CAPTCHA_VERIFICATION_URL, SiteSetting.recaptcha_secret_key)
    end
  end
end
