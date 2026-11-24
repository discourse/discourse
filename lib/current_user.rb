# frozen_string_literal: true

module CurrentUser
  def self.has_auth_cookie?(env)
    Discourse.current_user_provider.new(env).has_auth_cookie?
  end

  def self.lookup_from_env(env)
    Discourse.current_user_provider.new(env).current_user
  end

  # can be used to pretend current user does no exist, for CSRF attacks
  def clear_current_user
    @current_user_provider = Discourse.current_user_provider.new({})
  end

  def log_on_user(user, opts = {}, replay_anonymous_action: false)
    # The anonymous exchange is the only login path for a shadow, regardless of provider.
    raise Discourse::InvalidAccess if !opts[:anonymous_mode_exchange] && user.anonymous_shadow?

    current_user_provider.log_on_user(user, session, cookies, opts)
    DB.after_commit { user.logged_in }
    AnonymousAction.consume(user, cookies) if replay_anonymous_action
  end

  def log_off_user(push_subscription: nil)
    current_user_provider.log_off_user(session, cookies, push_subscription:)
  end

  def start_impersonating_user(user)
    current_user_provider.start_impersonating_user(user)
  end

  def stop_impersonating_user
    current_user_provider.stop_impersonating_user
  end

  def is_api?
    current_user_provider.is_api?
  end

  def is_user_api?
    current_user_provider.is_user_api?
  end

  def current_user
    current_user_provider.current_user
  rescue Discourse::InvalidAccess => e
    e.opts[:authentication_failed] = true
    raise
  end

  def impersonation_acting_user
    current_user_provider.impersonation_acting_user
  end

  def refresh_session(user)
    current_user_provider.refresh_session(user, session, cookies)
  end

  private

  # Serialize operations that derive a new credential from the incoming browser
  # session with revocation, and never rely on authentication cached before the lock.
  def with_authenticated_session
    source = current_user
    raise Discourse::InvalidAccess unless source

    source.with_credential_lock do |identity|
      unless identity&.active? && !identity.suspended? && !identity.anonymous_shadow?
        raise Discourse::InvalidAccess
      end
      provider = current_user_provider
      unless provider.respond_to?(:authenticated_session_user) &&
               provider.authenticated_session_user == source
        raise Discourse::InvalidAccess
      end
      yield identity
    end
  end

  def current_user_provider
    @current_user_provider ||= Discourse.current_user_provider.new(request.env)
  end
end
