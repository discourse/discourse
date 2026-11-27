# frozen_string_literal: true

module DiscourseCaptcha
  module SessionControllerPatch
    LOGIN_CODE_CAPTCHA_KEY_PREFIX = "discourse_captcha_login_code_"
    LOGIN_CODE_CAPTCHA_TTL = 1.hour

    # The challenge is solved before any code is emailed, so bots cannot use
    # this endpoint to send mail to arbitrary addresses. Whether the address
    # belongs to an account must not change the response, so logins and
    # signups are challenged alike.
    def create_login_code
      if login_code_captcha_required? && login_code_captcha_proof.nil?
        if (error = captcha_verification_error)
          render json: { error: I18n.t(error) }
          return
        end

        server_session.set(
          login_code_captcha_key,
          { recaptcha_v3_score: SignupScore.recaptcha_v3_score },
          expires: LOGIN_CODE_CAPTCHA_TTL,
        )
      end

      super
    ensure
      SignupScore.reset
    end

    def process_verified_login_code(matched_user)
      # Invitations carry their own proof of trust and are never CAPTCHA-gated.
      if matched_user.nil? && params[:invite_key].blank? && (proof = login_code_captcha_proof)
        @login_code_signup_captcha_verified = true
        @login_code_signup_score = proof[:recaptcha_v3_score]
        SignupScore.recaptcha_v3_score = @login_code_signup_score
        return super
      end

      captcha_required = captcha_enabled? && captcha_required_for_login_code_signup?(matched_user)
      if captcha_required && (error = captcha_verification_error)
        render json: { error: I18n.t(error) }
        return
      end

      @login_code_signup_captcha_verified = true if captcha_required
      super
    ensure
      SignupScore.reset
    end

    def complete_verified_login_code_signup
      proof = verified_login_code_signup_proof_for(params[:signup_token].to_s)
      if proof.is_a?(Hash) && proof[:captcha_verified]
        SignupScore.recaptcha_v3_score = proof[:recaptcha_v3_score]
      elsif proof.is_a?(Hash) && (error = captcha_verification_error)
        render json: { error: I18n.t(error) }
        return
      end

      super
    ensure
      SignupScore.reset
    end

    def verified_login_code_signup_proof
      super.merge(
        captcha_verified: @login_code_signup_captcha_verified,
        recaptcha_v3_score: @login_code_signup_score,
      )
    end

    private

    def captcha_enabled?
      SiteSetting.discourse_captcha_enabled &&
        SiteSetting.discourse_captcha_provider != CaptchaProvider::NONE
    end

    def login_code_captcha_required?
      captcha_enabled? && params[:invite_key].blank? && !is_api?
    end

    def login_code_captcha_proof
      return if params[:email].blank?

      proof = server_session[login_code_captcha_key]
      proof if proof.is_a?(Hash)
    end

    def login_code_captcha_key
      email = params[:email].to_s.strip.downcase
      "#{LOGIN_CODE_CAPTCHA_KEY_PREFIX}#{Digest::SHA256.hexdigest(email)}"
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
