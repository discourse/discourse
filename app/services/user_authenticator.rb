# frozen_string_literal: true

class UserAuthenticator

  def initialize(user, session, authenticator_finder: Users::OmniauthCallbacksController, require_password: true)
    @user = user
    @session = session
    if session&.dig(:authentication) && session[:authentication].is_a?(Hash)
      @auth_result = Auth::Result.from_session_data(session[:authentication], user: user)
    end
    @authenticator_finder = authenticator_finder
    @require_password = require_password
  end

  def start
    if authenticated?
      @user.active = true
      @auth_result.apply_user_attributes!
    elsif @require_password
      @user.password_required!
    end

    @user.skip_email_validation = true if @auth_result && @auth_result.skip_email_validation
  end

  def has_authenticator?
    !!authenticator
  end

  def finish
    if authenticator
      authenticator.after_create_account(@user, @auth_result)
      confirm_email
    end
    @session[:authentication] = @auth_result = nil if @session&.dig(:authentication)
  end

  def email_valid?
    @auth_result&.email_valid
  end

  def authenticated?
    return false if !@auth_result
    return false if @auth_result&.email&.downcase != @user.email.downcase
    return false if !@auth_result.email_valid
    true
  end

  private

  def confirm_email
    @user.activate if authenticated?
  end

  def authenticator
    if authenticator_name
      @authenticator ||= @authenticator_finder.find_authenticator(authenticator_name)
    end
  end

  def authenticator_name
    @auth_result&.authenticator_name
  end

end
