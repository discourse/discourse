# frozen_string_literal: true

module Auth
  module SessionConfirmation
    FRESH_LOGIN_SESSION_KEY = "fresh-login-session"
    FRESH_LOGIN_LIFETIME = 5.minutes
    CONFIRMED_SESSION_KEY = "confirmed-session"
    EMAIL_CODE_SESSION_KEY = "confirm-session-email-code"
    EXTERNAL_CONFIRM_KEY = "confirm-session-external"
    EXTERNAL_CONFIRM_LIFETIME = 5.minutes

    def self.browser_token(request, user)
      return if !user || user.anonymous? || user.is_impersonating
      return if request.env[Auth::DefaultCurrentUserProvider::API_KEY_ENV]
      return if request.env[Auth::DefaultCurrentUserProvider::USER_API_KEY_ENV]
      return if request.env["HTTP_X_SHARED_SESSION_KEY"].present?

      token = request.env[Auth::DefaultCurrentUserProvider::USER_TOKEN_KEY]
      token if token && token.user_id == user.id
    end

    def self.mark_fresh_login!(request, user, expires_at: FRESH_LOGIN_LIFETIME.from_now.to_i)
      ttl = expires_at - Time.now.to_i
      return if ttl <= 0

      token = browser_token(request, user)
      return if !token

      request.server_session.set(
        FRESH_LOGIN_SESSION_KEY,
        [user.id, token.id, expires_at],
        expires: ttl,
      )
    end

    def self.fresh_login?(request, user)
      token = browser_token(request, user)
      return false if !token

      user_id, token_id, expires_at = request.server_session[FRESH_LOGIN_SESSION_KEY]
      user_id == user.id && token_id == token.id && expires_at.to_i > Time.now.to_i
    end

    def self.mark_confirmed!(request, user, local: true)
      token = browser_token(request, user)
      return false if !token

      request.server_session[CONFIRMED_SESSION_KEY] = [user.id, token.id, !!local]
      true
    end

    def self.confirmed?(request, user, local_logins_available:)
      token = browser_token(request, user)
      return false if !token

      stored = request.server_session[CONFIRMED_SESSION_KEY]
      return false unless stored.is_a?(Array)

      user_id, token_id, is_local = stored
      return false unless user_id == user.id && token_id == token.id
      return false if is_local && !local_logins_available

      true
    end

    def self.issue_email_code!(request, user)
      token = browser_token(request, user)
      return if !token

      login_code = EmailLoginCode.generate!(email: user.email, purpose: :session_confirmation)
      request.server_session.set(
        EMAIL_CODE_SESSION_KEY,
        { login_code_id: login_code.id, user_id: user.id, token_id: token.id },
        expires: EmailLoginCode::VALID_FOR,
      )
      Jobs.enqueue(
        :send_session_confirmation_code,
        user_id: user.id,
        to_address: login_code.email,
        code: login_code.code,
      )
      login_code
    end

    def self.verify_email_code!(request, user, submitted_code)
      token = browser_token(request, user)
      return false if !token

      code = submitted_code.to_s.strip
      return false unless code.match?(/\A\d{#{EmailLoginCode::CODE_LENGTH}}\z/o)

      stored = request.server_session[EMAIL_CODE_SESSION_KEY]
      return false unless stored.is_a?(Hash)

      stored = stored.symbolize_keys
      return false unless stored[:user_id] == user.id && stored[:token_id] == token.id

      login_code = EmailLoginCode.session_confirmation.active.find_by(id: stored[:login_code_id])
      if !login_code || !user.email.casecmp?(login_code.email)
        request.server_session.delete(EMAIL_CODE_SESSION_KEY)
        return false
      end

      unless login_code.verify(code)
        if login_code.attempts >= EmailLoginCode::MAX_ATTEMPTS
          request.server_session.delete(EMAIL_CODE_SESSION_KEY)
        end
        return false
      end

      unless login_code.consume!
        request.server_session.delete(EMAIL_CODE_SESSION_KEY)
        return false
      end

      request.server_session.delete(EMAIL_CODE_SESSION_KEY)
      mark_confirmed!(request, user, local: true)
    end

    def self.start_external_confirmation!(request, user, provider:)
      return false if provider.blank?

      token = browser_token(request, user)
      return false if !token

      request.server_session.set(
        EXTERNAL_CONFIRM_KEY,
        { user_id: user.id, token_id: token.id, provider: provider.to_s },
        expires: EXTERNAL_CONFIRM_LIFETIME,
      )
    end

    def self.consume_external_confirmation!(request)
      data = request.server_session[EXTERNAL_CONFIRM_KEY]
      return unless data.is_a?(Hash)

      request.server_session.delete(EXTERNAL_CONFIRM_KEY)
      data.symbolize_keys
    end

    def self.clear_external_confirmation!(request)
      request.server_session.delete(EXTERNAL_CONFIRM_KEY)
    end

    def self.connected_external_providers(user)
      return [] if SiteSetting.enable_discourse_connect || !user || user.anonymous?

      Discourse
        .enabled_auth_providers
        .select do |provider|
          provider.custom_url.blank? && provider.authenticator.description_for_user(user).present?
        end
        .map { |provider| provider.authenticator.name }
    end
  end
end
