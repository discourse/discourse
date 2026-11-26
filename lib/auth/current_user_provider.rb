# frozen_string_literal: true

module Auth
end

class Auth::CurrentUserProvider
  # do all current user initialization here
  def initialize(env)
    raise NotImplementedError
  end

  # our current user, return nil if none is found
  def current_user
    raise NotImplementedError
  end

  # Optional: under the credential lock, re-read the incoming browser session
  # and return its directly authenticated user. Never return a cached identity.
  # Providers that cannot revalidate a browser session cannot switch anonymous
  # mode or register browser push subscriptions.
  def authenticated_session_user
    nil
  end

  # Optional: under the credential lock, re-read whichever credential
  # authenticated this request and return its user, so a credential issued for
  # the request cannot outlive a password change that revoked it. Providers
  # whose sessions are not the core tokens a password change revokes have
  # nothing to re-read, so the default keeps them working.
  def authenticated_credential_user
    current_user
  end

  # anonymous_mode_exchange is the locked master of the validated browser session.
  # Replace its current token atomically, keeping one revocation target without
  # letting a retired cookie authenticate.
  def log_on_user(user, session, cookie_jar, opts = {})
    raise NotImplementedError
  end

  # optional interface to be called to refresh cookies etc if needed
  def refresh_session(user, session, cookie_jar)
  end

  # Optional interface for implementing impersonation.
  def start_impersonating_user(user)
  end

  # Optional interface for implementing impersonation.
  def stop_impersonating_user
  end

  # Optional interface for implementing impersonation.
  def impersonation_acting_user
  end

  # api has special rights return true if api was detected
  def is_api?
    raise NotImplementedError
  end

  def is_user_api?
    raise NotImplementedError
  end

  # we may need to know very early on in the middleware if an auth token
  # exists, to optimise caching
  def has_auth_cookie?
    raise NotImplementedError
  end

  def log_off_user(session, cookie_jar, push_subscription: nil)
    raise NotImplementedError
  end
end
