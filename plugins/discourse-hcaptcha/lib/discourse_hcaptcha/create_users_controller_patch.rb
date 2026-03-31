# frozen_string_literal: true

module DiscourseHcaptcha
  module CreateUsersControllerPatch
    extend ActiveSupport::Concern
    included { before_action :check_captcha, only: [:create] }

    def check_captcha
      captcha_provider = captcha_provider_selector
      return if captcha_provider.nil?

      captcha_token = captcha_provider.fetch_captcha_token(cookies)
      raise Discourse::InvalidAccess.new if captcha_token.blank?

      response = captcha_provider.send_captcha_verification(captcha_token)

      validate_captcha_response(response)
    rescue => e
      Rails.logger.warn("Error parsing Captcha response: #{e}")
      fail_with("captcha_verification_failed")
    end

    private

    def captcha_provider_selector
      if SiteSetting.discourse_hcaptcha_enabled && SiteSetting.hcaptcha_site_key.present? &&
           SiteSetting.hcaptcha_secret_key.present?
        DiscourseHcaptcha::HcaptchaProvider.new
      elsif SiteSetting.discourse_recaptcha_enabled && SiteSetting.recaptcha_site_key.present? &&
            SiteSetting.recaptcha_secret_key.present?
        DiscourseHcaptcha::RecaptchaProvider.new
      end
    end

    def validate_captcha_response(response)
      raise Discourse::InvalidAccess.new if response.code.to_i >= 500
      response_json = JSON.parse(response.body)
      if response_json["success"].nil? || response_json["success"] == false
        raise Discourse::InvalidAccess.new
      end
    end
  end
end
