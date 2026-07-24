# frozen_string_literal: true

module DiscourseCaptcha
  class RecaptchaController < DiscourseCaptcha::CaptchaController
    requires_plugin PLUGIN_NAME

    private

    def ensure_config
      if SiteSetting.discourse_captcha_provider != CaptchaProvider::RECAPTCHA
        raise Discourse::NotFound
      end
      raise Discourse::InvalidParameters.new(:token) if params[:token].blank?
    end

    def token_key
      "recaptcha_token"
    end
  end
end
