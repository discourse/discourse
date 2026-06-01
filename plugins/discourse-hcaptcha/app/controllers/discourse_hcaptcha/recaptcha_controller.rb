# frozen_string_literal: true

module DiscourseHcaptcha
  class RecaptchaController < DiscourseHcaptcha::CaptchaController
    requires_plugin PLUGIN_NAME

    private

    def ensure_config
      unless SiteSetting.discourse_captcha_provider == CaptchaProvider::RECAPTCHA
        raise Discourse::NotFound
      end
      raise Discourse::InvalidParameters.new(:token) if params[:token].blank?
    end

    def store_token_in_redis(temp_id)
      Discourse.redis.setex("reCaptchaToken_#{temp_id}", TOKEN_TTL.to_i, params[:token])
    end

    def set_encrypted_cookie(temp_id)
      cookies.encrypted[:re_captcha_temp_id] = cookie_options.merge({ value: temp_id })
    end
  end
end
