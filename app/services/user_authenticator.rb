class UserAuthenticator

  def initialize(user, session, authenticator_finder = Users::OmniauthCallbacksController)
    @user = user
    @session = session[:authentication]
    @authenticator_finder = authenticator_finder
  end

  def start
    if authenticated?
      @user.active = true
    else
      @user.password_required!
    end
  end

  def has_authenticator?
    !!authenticator
  end

  def finish
    authenticator.after_create_account(@user, @session) if authenticator
    @session = nil
  end

  private

  def authenticated?
    @session && @session[:email] == @user.email && @session[:email_valid]
  end

  def authenticator
    if authenticator_name
      @authenticator ||= @authenticator_finder.find_authenticator(authenticator_name)
    end
  end

  def authenticator_name
    @session && @session[:authenticator_name]
  end

end
