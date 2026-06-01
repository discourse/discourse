# frozen_string_literal: true

module DiscourseHcaptcha
  class CaptchaController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    before_action :ensure_config
    skip_before_action :redirect_to_login_if_required

    TOKEN_TTL = 2.minutes

    def create
      temp_id = SecureRandom.uuid
      store_token_in_redis(temp_id)
      set_encrypted_cookie(temp_id)

      render json: { success: "OK" }
    end

    private

    def ensure_config
      raise NotImplementedError
    end

    def store_token_in_redis(temp_id)
      raise NotImplementedError
    end

    def set_encrypted_cookie(temp_id)
      raise NotImplementedError
    end

    def cookie_options
      options = { httponly: true, secure: SiteSetting.force_https, expires: TOKEN_TTL.from_now }
      options[:same_site] = SiteSetting.same_site_cookies if SiteSetting.same_site_cookies !=
        "Disabled"
      options
    end
  end
end
