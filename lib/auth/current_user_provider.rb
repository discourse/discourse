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

  # log on a user and set cookies and session etc.
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

  def log_off_user(session, cookie_jar)
    raise NotImplementedError
  end
end
