# frozen_string_literal: true

module DiscourseCaptcha
  # Configuration testing must remain available before CAPTCHA enforcement is enabled.
  class AdminCaptchaController < ::Admin::AdminController # rubocop:disable Discourse/Plugins/CallRequiresPlugin
    def show
      respond_to do |format|
        format.html { render body: nil }
        format.json { render json: ConfigurationTest.new.configuration }
      end
    end

    def verify
      token = params.require(:token)
      raise Discourse::InvalidParameters.new(:token) if !token.is_a?(String) || token.size > 16_384

      test = ConfigurationTest.new
      configuration = test.configuration
      if params[:provider] != configuration[:provider] ||
           params[:site_key].to_s != configuration[:site_key].to_s
        raise Discourse::InvalidParameters.new(
                I18n.t("discourse_captcha.configuration_test.errors.configuration_changed"),
              )
      end

      RateLimiter.new(current_user, "captcha_configuration_test", 10, 1.minute).performed!
      render json: test.verify(token)
    end
  end
end
