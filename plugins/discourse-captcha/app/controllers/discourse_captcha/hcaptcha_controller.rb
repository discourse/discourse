# frozen_string_literal: true

module DiscourseCaptcha
  class HcaptchaController < DiscourseCaptcha::CaptchaController
    requires_plugin PLUGIN_NAME

    private

    def ensure_config
      unless SiteSetting.discourse_captcha_provider == CaptchaProvider::HCAPTCHA
        raise Discourse::NotFound
      end
      raise Discourse::InvalidParameters.new(:token) if params[:token].blank?
    end

    def token_key
      "hcaptcha_token"
    end
  end
end
