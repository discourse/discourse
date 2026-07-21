# frozen_string_literal: true

module DiscourseCaptcha
  class CaptchaController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    before_action :ensure_config
    skip_before_action :redirect_to_login_if_required

    TOKEN_TTL = 2.minutes

    def create
      server_session.set(token_key, params[:token], expires: TOKEN_TTL)
      render json: { success: "OK" }
    end

    private

    def ensure_config
      raise NotImplementedError
    end

    def token_key
      raise NotImplementedError
    end
  end
end
