# frozen_string_literal: true

module DiscourseHcaptcha
  module CreateUsersControllerPatch
    extend ActiveSupport::Concern
    included { before_action :check_captcha, only: [:create] }

    def check_captcha
      return unless SiteSetting.discourse_captcha_enabled
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
      hcaptcha_configured =
        SiteSetting.discourse_hcaptcha_enabled && SiteSetting.hcaptcha_site_key.present? &&
          SiteSetting.hcaptcha_secret_key.present?
      recaptcha_configured =
        SiteSetting.discourse_recaptcha_enabled && SiteSetting.recaptcha_site_key.present? &&
          SiteSetting.recaptcha_secret_key.present?

      if hcaptcha_configured && recaptcha_configured
        Rails.logger.warn(
          "Both hCaptcha and reCaptcha are enabled. Using hCaptcha as the captcha provider.",
        )
      end

      if hcaptcha_configured
        DiscourseHcaptcha::HcaptchaProvider.new
      elsif recaptcha_configured
        DiscourseHcaptcha::RecaptchaProvider.new
      else
        if SiteSetting.discourse_captcha_enabled
          Rails.logger.warn(
            "Captcha plugin is enabled but no captcha provider is properly configured. " \
              "Please configure either hCaptcha or reCaptcha in site settings.",
          )
        end
        nil
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
