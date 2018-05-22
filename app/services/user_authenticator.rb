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

    @user.skip_email_validation = true if @session && @session[:skip_email_validation].present?
  end

  def has_authenticator?
    !!authenticator
  end

  def finish
    if authenticator
      authenticator.after_create_account(@user, @session)
      confirm_email
    end
    @session = nil
  end

  def email_valid?
    @session && @session[:email_valid]
  end

  def authenticated?
    @session && @session[:email]&.downcase == @user.email.downcase && @session[:email_valid].to_s == "true"
  end

  private

  def confirm_email
    if authenticated?
      EmailToken.confirm(@user.email_tokens.first.token)
      @user.set_automatic_groups
    end
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
