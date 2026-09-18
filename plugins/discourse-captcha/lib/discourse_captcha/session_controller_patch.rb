# frozen_string_literal: true

module DiscourseCaptcha
  module SessionControllerPatch
    def process_verified_login_code(matched_user)
      # Invitations carry their own proof of trust and are never CAPTCHA-gated.
      captcha_required = captcha_enabled? && captcha_required_for_login_code_signup?(matched_user)
      if captcha_required && (error = captcha_verification_error)
        render json: { error: I18n.t(error) }
        return
      end

      @login_code_signup_captcha_verified = true if captcha_required
      super
    end

    def complete_verified_login_code_signup
      proof = verified_login_code_signup_proof_for(params[:signup_token].to_s)
      if proof.is_a?(Hash) && !proof[:captcha_verified] && (error = captcha_verification_error)
        render json: { error: I18n.t(error) }
        return
      end

      super
    end

    def verified_login_code_signup_proof
      super.merge(captcha_verified: @login_code_signup_captcha_verified)
    end

    private

    def captcha_enabled?
      SiteSetting.discourse_captcha_enabled &&
        SiteSetting.discourse_captcha_provider != CaptchaProvider::NONE
    end

    def captcha_required_for_login_code_signup?(matched_user)
      return false if matched_user.present? || params[:invite_key].present?
      return false if !registration_via_login_code_open?

      !pending_approval_signup?(matched_user) && params[:username].present? &&
        !signup_user_fields_missing? && !signup_full_name_missing?
    end

    include CaptchaVerification
  end
end
