class HerokuSession

  attr_reader :controller, :cookies, :session, :logged_in_forum, :logged_in_heroku

  def initialize(controller)
    @controller = controller
    @cookies = controller.send :cookies
    @session = controller.session
    @logged_in_forum = !!controller.current_user
    @logged_in_heroku = cookies[:heroku_session].present?
  end

  def sync
    if logged_in_forum && !logged_in_heroku
      destroy
      controller.redirect_to controller.request.path
    elsif logged_in_as_different_user? || (!logged_in_forum && logged_in_heroku)
      dance_oauth
    end
  end

  def create(oauth_token)
    user_info = HerokuUserInfo.find_or_create_from_oauth_token(oauth_token)
    user = user_info.user
    controller.log_on_user(user)
    set_cookies
  end

  def destroy
    unset_cookies
    controller.reset_session
  end

  private

  def dance_oauth
    controller.redirect_to(controller.new_heroku_session_path(:back_to => controller.request.path))
  end

  def logged_in_as_different_user?
    different_cookies = cookies[:heroku_session_nonce].present? && (cookies[:heroku_session_nonce] != cookies[:forums_session_nonce])
    logged_in_forum && logged_in_heroku && different_cookies
  end

  # cookies

  def set_cookies
    cookies[:forums_session_nonce] = cookies[:heroku_session_nonce]
    cookies[:heroku_session] = {value: '1', domain: heroku_cookies_domain } if cookies[:heroku_session].blank?
  end

  def unset_cookies
    cookies.delete(:forums_session_nonce)
    cookies.delete('heroku_session', :domain => heroku_cookies_domain)
    cookies.delete('heroku_session_nonce', :domain => heroku_cookies_domain)
    cookies.delete(:_t)
  end

  def heroku_cookies_domain
    '.heroku.com'
  end

end