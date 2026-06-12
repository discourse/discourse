# frozen_string_literal: true

module DiscourseCaptcha
  module CreateUsersControllerPatch
    extend ActiveSupport::Concern
    included { before_action :check_captcha, only: [:create] }

    def check_captcha
      return unless SiteSetting.discourse_captcha_enabled
      return if SiteSetting.discourse_captcha_provider == CaptchaProvider::NONE

      captcha_provider = captcha_provider_selector
      return fail_with("captcha_not_configured") if captcha_provider.nil?

      captcha_token = captcha_provider.fetch_captcha_token(server_session)
      raise Discourse::InvalidAccess.new if captcha_token.blank?

      response = captcha_provider.send_captcha_verification(captcha_token)

      validate_captcha_response(response)
    rescue Discourse::InvalidAccess
      fail_with("captcha_verification_failed")
    rescue StandardError => e
      Rails.logger.warn("Captcha verification error: #{e.class} - #{e.message}")
      fail_with("captcha_verification_failed")
    end

    private

    def captcha_provider_selector
      case SiteSetting.discourse_captcha_provider
      when CaptchaProvider::HCAPTCHA
        if SiteSetting.hcaptcha_site_key.present? && SiteSetting.hcaptcha_secret_key.present?
          DiscourseCaptcha::HcaptchaProvider.new
        end
      when CaptchaProvider::RECAPTCHA
        if SiteSetting.recaptcha_site_key.present? && SiteSetting.recaptcha_secret_key.present?
          DiscourseCaptcha::RecaptchaProvider.new
        end
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
