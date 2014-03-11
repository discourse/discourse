require_dependency "auth/current_user_provider"

class Auth::LpCurrentUserProvider < Auth::DefaultCurrentUserProvider
  def log_on_user(user, session, cookies)
    super
    set_cookies(cookies)
  end


  def log_off_user(session, cookies)
    super
    unset_cookies(cookies)
  end

  private

  def set_cookies(cookies)
    cookies[:forums_session_nonce] = cookies[LpSession::NOONCE_COOKIE_NAME]
    cookies[LpSession::SESSION_COOKIE_NAME] = { value: '1', domain: cookies_domain } if cookies[LpSession::SESSION_COOKIE_NAME].blank?
  end

  def unset_cookies(cookies)
    cookies.delete(:forums_session_nonce)
    cookies.delete(LpSession::SESSION_COOKIE_NAME, :domain => cookies_domain)
    cookies.delete(LpSession::NOONCE_COOKIE_NAME, :domain => cookies_domain)
  end

  def cookies_domain
    ENV['COOKIE_DOMAIN']
  end
end
