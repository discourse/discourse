# frozen_string_literal: true

module DiscourseCaptcha
  module CreateUsersControllerPatch
    extend ActiveSupport::Concern

    included { before_action :check_captcha, only: [:create] }

    def check_captcha
      return unless (error = captcha_verification_error)

      fail_with(error)
    end

    include CaptchaVerification
  end
end
