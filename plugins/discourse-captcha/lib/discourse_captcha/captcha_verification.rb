# frozen_string_literal: true

module DiscourseCaptcha
  module CaptchaVerification
    private

    def captcha_verification_error
      return unless SiteSetting.discourse_captcha_enabled
      return if SiteSetting.discourse_captcha_provider == CaptchaProvider::NONE

      captcha_provider = captcha_provider_selector
      return :captcha_not_configured if captcha_provider.nil?

      captcha_token = captcha_provider.fetch_captcha_token(server_session)
      return :captcha_verification_failed if captcha_token.blank?

      captcha_provider.validate_captcha_response(
        captcha_provider.send_captcha_verification(captcha_token),
      )
      nil
    rescue StandardError => e
      Rails.logger.warn("Captcha verification error: #{e.class} - #{e.message}")
      :captcha_verification_failed
    end

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
      when CaptchaProvider::RECAPTCHA_V3
        if SiteSetting.recaptcha_v3_site_key.present? &&
             SiteSetting.recaptcha_v3_secret_key.present?
          DiscourseCaptcha::RecaptchaV3Provider.new
        end
      end
    end
  end
end
