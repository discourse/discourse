# frozen_string_literal: true

module DiscourseCaptcha
  class CaptchaProvider
    HCAPTCHA = "hcaptcha"
    RECAPTCHA_V2 = "recaptcha_v2"
    RECAPTCHA_V3 = "recaptcha_v3"
    NONE = "none"

    def fetch_captcha_token(server_session)
      raise NotImplementedError
    end

    def captcha_verification_url
      raise NotImplementedError
    end

    def send_captcha_verification(captcha_token)
      raise NotImplementedError
    end

    def validate_captcha_response(response)
      raise Discourse::InvalidAccess if response.code.to_i >= 500

      response_json = JSON.parse(response.body)
      if response_json["success"].nil? || response_json["success"] == false
        raise Discourse::InvalidAccess
      end

      response_json
    end

    protected

    def send_verification(captcha_token, captcha_verification_url, secret_key)
      uri = URI.parse(captcha_verification_url)

      http = FinalDestination::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = FinalDestination::HTTP::Post.new(uri.request_uri)
      request.set_form_data({ "secret" => secret_key, "response" => captcha_token })

      http.request(request)
    end
  end
end
