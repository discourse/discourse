# frozen_string_literal: true

module ::DiscourseHcaptcha
  class HcaptchaController < DiscourseHcaptcha::CaptchaController
    requires_plugin DiscourseHcaptcha::PLUGIN_NAME

    private

    def ensure_config
      raise "not enabled" unless SiteSetting.discourse_hcaptcha_enabled
      raise "token is missing" if params[:token].blank?
    end

    def store_token_in_redis(temp_id)
      Discourse.redis.setex("hCaptchaToken_#{temp_id}", TOKEN_TTL.to_i, params[:token])
    end

    def set_encrypted_cookie(temp_id)
      cookies.encrypted[:h_captcha_temp_id] = cookie_options.merge({ value: temp_id })
    end
  end
end
