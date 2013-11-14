class LpSession

  attr_reader :controller, :cookies, :session, :logged_in_forum, :logged_in_lessonplanet

  SESSION_COOKIE_NAME = ENV['MAIN_SITE_COOKIE_NAME']
  NOONCE_COOKIE_NAME = "#{SESSION_COOKIE_NAME}_noonce"

  def initialize(controller)
    @controller = controller
    @cookies = controller.send :cookies
    @session = controller.session
    @logged_in_forum = !!controller.current_user
    @logged_in_lessonplanet = cookies[SESSION_COOKIE_NAME].present?
  end

  def sync
    if logged_in_forum && !logged_in_lessonplanet
      destroy
      controller.redirect_to controller.request.path
    elsif logged_in_as_different_user? || (!logged_in_forum && logged_in_lessonplanet)
      dance_oauth
    end
  end

  def create(oauth_token)
    user_info = LpUserInfo.find_or_create_from_oauth_token(oauth_token)
    user = user_info.user
    controller.log_on_user(user)
    set_cookies(user_info)
  end

  def destroy
    unset_cookies
    controller.reset_session
  end

  private

  def dance_oauth
    controller.redirect_to(controller.new_lp_session_path(:back_to => controller.request.path))
  end

  def logged_in_as_different_user?
    different_cookies = cookies[NOONCE_COOKIE_NAME].present? && (cookies[NOONCE_COOKIE_NAME] != cookies[NOONCE_COOKIE_NAME])
    logged_in_forum && logged_in_lessonplanet && different_cookies
  end

  # cookies

  def set_cookies(user_info)
    cookies[:forums_session_nonce] = cookies[NOONCE_COOKIE_NAME]
    cookies[SESSION_COOKIE_NAME] = {value: '1', domain: cookies_domain } if cookies[SESSION_COOKIE_NAME].blank?

    # Used by DevCenter::Logger middleware to track page visits.
    creds = LpCredentials.new(email: user_info.user.email, lessonplanet_uid: user_info.lp_user_id)
    cookies[:user_info] = creds.encrypt
  end

  def unset_cookies
    cookies.delete(:forums_session_nonce)
    cookies.delete(SESSION_COOKIE_NAME, :domain => cookies_domain)
    cookies.delete(NOONCE_COOKIE_NAME, :domain => cookies_domain)
    cookies.delete(:user_info)
    cookies.delete(:_t)
  end

  def cookies_domain
    ENV['COOKIE_DOMAIN']
  end

end
