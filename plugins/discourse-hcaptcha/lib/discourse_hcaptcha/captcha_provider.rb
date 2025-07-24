# frozen_string_literal: true

module DiscourseHcaptcha
  class CaptchaProvider
    def fetch_captcha_token
      raise NotImplementedError
    end

    def captcha_verification_url
      raise NotImplementedError
    end

    def send_captcha_verification(captcha_token)
      raise NotImplementedError
    end

    protected

    def fetch_token(temp_id_key, redis_prefix, cookies)
      temp_id = cookies.encrypted[temp_id_key]
      captcha_token = Discourse.redis.get("#{redis_prefix}_#{temp_id}")

      if temp_id.present?
        Discourse.redis.del("#{redis_prefix}_#{temp_id}")
        cookies.delete(temp_id_key)
      end

      captcha_token
    end

    def send_verification(captcha_token, captcha_verification_url, secret_key)
      uri = URI.parse(captcha_verification_url)

      http = FinalDestination::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = FinalDestination::HTTP::Post.new(uri.request_uri)
      request.set_form_data({ "secret" => secret_key, "response" => captcha_token })

      http.request(request)
    end
  end

  class HcaptchaProvider < CaptchaProvider
    CAPTCHA_VERIFICATION_URL = "https://hcaptcha.com/siteverify".freeze
    def fetch_captcha_token(cookies)
      fetch_token(:h_captcha_temp_id, "hCaptchaToken", cookies)
    end

    def captcha_verification_url
      CAPTCHA_VERIFICATION_URL
    end
    def send_captcha_verification(captcha_token)
      send_verification(captcha_token, CAPTCHA_VERIFICATION_URL, SiteSetting.hcaptcha_secret_key)
    end
  end

  class RecaptchaProvider < CaptchaProvider
    CAPTCHA_VERIFICATION_URL = "https://www.google.com/recaptcha/api/siteverify".freeze

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
