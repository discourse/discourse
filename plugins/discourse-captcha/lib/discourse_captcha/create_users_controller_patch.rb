# frozen_string_literal: true

module DiscourseCaptcha
  module CreateUsersControllerPatch
    extend ActiveSupport::Concern
    included do
      around_action :discard_unused_signup_score, only: [:create]
      before_action :check_captcha, only: [:create]
    end

    # Not every deployment clears request-scoped state between requests.
    def discard_unused_signup_score
      yield
    ensure
      SignupScore.reset
    end

    def check_captcha
      return unless (error = captcha_verification_error)

      fail_with(error)
    end

    include CaptchaVerification
  end
end
