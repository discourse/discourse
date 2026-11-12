# frozen_string_literal: true

module DiscourseCaptcha
  # The captcha is verified before the account exists, so the score is held for
  # the rest of the request and persisted once the account is created.
  class SignupScore < ActiveSupport::CurrentAttributes
    CUSTOM_FIELD = "recaptcha_v3_signup_score"

    attribute :recaptcha_v3_score

    def self.assign_to(user)
      score = recaptcha_v3_score
      return if score.nil?

      reset
      user.custom_fields[CUSTOM_FIELD] = score
    end

    def self.persist_for(user)
      user.save_custom_fields if assign_to(user)
    end
  end
end
