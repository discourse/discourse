# frozen_string_literal: true

module DiscourseCaptcha
  class RecaptchaV3Provider < RecaptchaProvider
    CAPTCHA_VERIFICATION_URL = "https://www.google.com/recaptcha/api/siteverify"
    CAPTCHA_ACTION = "signup"

    def fetch_captcha_token(server_session)
      token = server_session["recaptcha_v3_token"]
      server_session.delete("recaptcha_v3_token")
      token
    end

    def send_captcha_verification(captcha_token)
      send_verification(
        captcha_token,
        CAPTCHA_VERIFICATION_URL,
        SiteSetting.recaptcha_v3_secret_key,
      )
    end

    def validate_captcha_response(response)
      response_json = super
      # reCAPTCHA v3 responses include `action` and `score`, but Google's test
      # keys omit them. Only enforce these checks when they are actually present.
      if response_json["action"].present? && response_json["action"] != CAPTCHA_ACTION
        raise Discourse::InvalidAccess
      end
      if response_json["score"].present? &&
           response_json["score"].to_f < SiteSetting.recaptcha_v3_score_threshold
        raise Discourse::InvalidAccess
      end

      response_json
    end
  end
end
