# frozen_string_literal: true

module DiscourseCaptcha
  class ConfigurationTest
    ERROR_MESSAGES = {
      "missing-input-secret" => "invalid_secret",
      "invalid-input-secret" => "invalid_secret",
      "sitekey-secret-mismatch" => "key_mismatch",
      "invalid-input-response" => "invalid_response",
      "missing-input-response" => "invalid_response",
      "invalid-or-already-seen-response" => "expired",
      "expired-input-response" => "expired",
      "timeout-or-duplicate" => "expired",
      "not-using-dummy-passcode" => "key_mismatch",
    }.freeze

    def initialize
      @provider = SiteSetting.discourse_captcha_provider
      case @provider
      when CaptchaProvider::RECAPTCHA
        @site_key = SiteSetting.recaptcha_site_key
        @secret_key = SiteSetting.recaptcha_secret_key
        @captcha_provider = RecaptchaProvider.new
      when CaptchaProvider::HCAPTCHA
        @site_key = SiteSetting.hcaptcha_site_key
        @secret_key = SiteSetting.hcaptcha_secret_key
        @captcha_provider = HcaptchaProvider.new
      end
    end

    def configuration
      {
        provider: @provider,
        site_key: @site_key,
        configured: @captcha_provider.present? && @site_key.present? && @secret_key.present?,
      }
    end

    def verify(token)
      return failure("not_configured") if !configuration[:configured]

      response = @captcha_provider.send_captcha_verification(token)
      return failure("unavailable") if response.code.to_i != 200

      result = JSON.parse(response.body)
      return failure("invalid_response") if !result.is_a?(Hash)

      if result["success"] == true
        { success: true, message: I18n.t("discourse_captcha.configuration_test.success") }
      else
        error = Array(result["error-codes"]).filter_map { |code| ERROR_MESSAGES[code] }.first
        failure(error || "verification_failed")
      end
    rescue JSON::ParserError
      failure("invalid_response")
    rescue Timeout::Error, SocketError, IOError, SystemCallError, OpenSSL::SSL::SSLError
      failure("unavailable")
    end

    private

    def failure(error)
      { success: false, message: I18n.t("discourse_captcha.configuration_test.errors.#{error}") }
    end
  end
end
