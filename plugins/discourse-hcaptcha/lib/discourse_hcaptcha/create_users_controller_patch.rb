# frozen_string_literal: true

module DiscourseHcaptcha
  module CreateUsersControllerPatch
    H_CAPTCHA_VERIFICATION_URL = "https://hcaptcha.com/siteverify".freeze

    extend ActiveSupport::Concern
    included { before_action :check_h_captcha, only: [:create] }

    def check_h_captcha
      return unless SiteSetting.discourse_hcaptcha_enabled

      h_captcha_token = fetch_h_captcha_token
      raise Discourse::InvalidAccess.new if h_captcha_token.blank?

      response = send_h_captcha_verification(h_captcha_token)

      validate_h_captcha_response(response)
    rescue => e
      Rails.logger.warn("Error parsing hCaptcha response: #{e}")
      fail_with("h_captcha_verification_failed")
    end

    private

    def send_h_captcha_verification(h_captcha_token)
      uri = URI.parse(H_CAPTCHA_VERIFICATION_URL)

      http = FinalDestination::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = FinalDestination::HTTP::Post.new(uri.request_uri)
      request.set_form_data(
        { "secret" => SiteSetting.hcaptcha_secret_key, "response" => h_captcha_token },
      )

      http.request(request)
    end

    def fetch_h_captcha_token
      temp_id = cookies.encrypted[:h_captcha_temp_id]
      h_captcha_token = Discourse.redis.get("hCaptchaToken_#{temp_id}")

      if temp_id.present?
        Discourse.redis.del("hCaptchaToken_#{temp_id}")
        cookies.delete(:h_captcha_temp_id)
      end

      h_captcha_token
    end

    def validate_h_captcha_response(response)
      raise Discourse::InvalidAccess.new if response.code.to_i >= 500

      response_json = JSON.parse(response.body)
      if response_json["success"].nil? || response_json["success"] == false
        raise Discourse::InvalidAccess.new
      end
    end
  end
end
