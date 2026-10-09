# frozen_string_literal: true

module DiscourseCaptcha
  class RecaptchaV3Controller < DiscourseCaptcha::CaptchaController
    requires_plugin PLUGIN_NAME

    private

    def ensure_config
      if SiteSetting.discourse_captcha_provider != CaptchaProvider::RECAPTCHA_V3
        raise Discourse::NotFound
      end
      raise Discourse::InvalidParameters.new(:token) if params[:token].blank?
    end

    def token_key
      "recaptcha_v3_token"
    end
  end
end
