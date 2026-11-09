# frozen_string_literal: true

module DiscourseCaptcha
  module CreateUsersControllerPatch
    extend ActiveSupport::Concern
    included { before_action :check_captcha, only: [:create] }

    def check_captcha
      error = captcha_verification_error
      return fail_with(error) if error

      if SiteSetting.discourse_captcha_provider == CaptchaProvider::RECAPTCHA_V3
        SignupScore.recaptcha_v3_score = @captcha_verification_response&.dig("score")
      end
    end

    include CaptchaVerification
  end
end
