# frozen_string_literal: true

class UserAuthenticator

  def initialize(user, session, authenticator_finder = Users::OmniauthCallbacksController)
    @user = user
    @session = session
    @auth_session = session[:authentication]
    @authenticator_finder = authenticator_finder
  end

  def start
    if authenticated?
      @user.active = true
    else
      @user.password_required!
    end

    @user.skip_email_validation = true if @auth_session && @auth_session[:skip_email_validation].present?
  end

  def has_authenticator?
    !!authenticator
  end

  def finish
    if authenticator
      authenticator.after_create_account(@user, @auth_session)
      confirm_email
    end
    @session[:authentication] = @auth_session = nil if @auth_session
  end

  def email_valid?
    @auth_session && @auth_session[:email_valid]
  end

  def authenticated?
    @auth_session && @auth_session[:email]&.downcase == @user.email.downcase && @auth_session[:email_valid].to_s == "true"
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
    @auth_session && @auth_session[:authenticator_name]
  end

end
