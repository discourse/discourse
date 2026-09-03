# frozen_string_literal: true

module DiscourseCaptcha
  module SessionControllerPatch
    def process_verified_login_code(matched_user)
      if matched_user.nil? && registration_via_login_code_open? &&
           (error = captcha_verification_error)
        render json: { error: I18n.t(error) }
        return
      end

      super
    end

    include CaptchaVerification
  end
end
