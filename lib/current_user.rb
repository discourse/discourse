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

  def log_on_user(user, opts = {})
    current_user_provider.log_on_user(user, session, cookies, opts)
    user.logged_in
  end

  def log_off_user
    current_user_provider.log_off_user(session, cookies)
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
  end

  def refresh_session(user)
    current_user_provider.refresh_session(user, session, cookies)
  end

  private

  def current_user_provider
    @current_user_provider ||= Discourse.current_user_provider.new(request.env)
  end
end
