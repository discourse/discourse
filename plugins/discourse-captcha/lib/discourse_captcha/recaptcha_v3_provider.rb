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

    def validate_captcha_response(
      response,
      action: CAPTCHA_ACTION,
      score_threshold: SiteSetting.recaptcha_v3_score_threshold
    )
      response_json = super(response)
      raise Discourse::InvalidAccess if response_json["action"] != action

      score = response_json["score"]
      raise Discourse::InvalidAccess if !score.is_a?(Numeric) || score < score_threshold

      response_json
    end
  end
end
