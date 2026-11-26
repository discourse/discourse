# frozen_string_literal: true

module Auth
  module SecondFactorEnrollment
    SESSION_KEY = "second-factor-external-login"
    PROOF_LIFETIME = 5.minutes

    def self.mark_external_login!(request, user, expires_at: PROOF_LIFETIME.from_now.to_i)
      ttl = expires_at - Time.now.to_i
      return if ttl <= 0

      token = external_token(request, user)
      return if !token

      request.server_session.set(SESSION_KEY, [user.id, token.id, expires_at], expires: ttl)
    end

    def self.recent_external_login?(request, user)
      token = external_token(request, user)
      return false if !token

      user_id, token_id, expires_at = request.server_session[SESSION_KEY]
      user_id == user.id && token_id == token.id && expires_at > Time.now.to_i
    end

    def self.external_token(request, user)
      token = request.env[Auth::DefaultCurrentUserProvider::USER_TOKEN_KEY]
      if token&.authenticated_with_oauth? && token.user_id == user.id && !user.is_impersonating
        token
      end
    end
    private_class_method :external_token
  end
end
