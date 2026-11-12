# frozen_string_literal: true

module DiscourseCaptcha
  class HcaptchaProvider < CaptchaProvider
    CAPTCHA_VERIFICATION_URL = "https://hcaptcha.com/siteverify"

    def fetch_captcha_token(server_session)
      token = server_session["hcaptcha_token"]
      server_session.delete("hcaptcha_token")
      token
    end

    def captcha_verification_url
      CAPTCHA_VERIFICATION_URL
    end

    def send_captcha_verification(captcha_token)
      send_verification(captcha_token, CAPTCHA_VERIFICATION_URL, SiteSetting.hcaptcha_secret_key)
    end
  end
end
