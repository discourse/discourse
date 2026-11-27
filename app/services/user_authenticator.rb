# frozen_string_literal: true

class UserAuthenticator
  attr_reader :enrollment_proof_expires_at

  def initialize(
    user,
    session,
    authenticator_finder: Users::OmniauthCallbacksController,
    require_password: true
  )
    @user = user
    @session = session
    @authentication_data = session.try(:[], :authentication)
    if @authentication_data.is_a?(Hash)
      @auth_result = Auth::Result.from_session_data(@authentication_data, user: user)
    end
    @authenticator_finder = authenticator_finder
    @require_password = require_password
  end

  def start
    if authenticated?
      @user.active = true
      @auth_result.apply_user_attributes!
    end

    @user.password_required! if !@auth_result && @require_password
    @user.skip_email_validation = true if @auth_result && @auth_result.skip_email_validation
  end

  def has_authenticator?
    !!authenticator
  end

  def finish
    if authenticator
      authenticator.after_create_account(@user, @auth_result)
      if authenticated?
        @user.activate
        @enrollment_proof_expires_at = @authentication_data[:enrollment_proof_expires_at]
      end
    end
    if @session.try(:[], :authentication)
      @session.delete(:authentication)
      @auth_result = nil
      @session[:authenticated_with_oauth] = true
    end
  end

  def email_valid?
    @auth_result&.email_valid
  end

  def unstage!(signup_email:)
    if @user.email == signup_email && authenticated? && @auth_result.skip_email_validation
      @user.skip_email_validation = true
    end
    @user.unstage!
  end

  def authenticated?
    return false if !@auth_result
    return false if @auth_result&.email&.downcase != @user.email.downcase
    return false if !@auth_result.email_valid
    true
  end

  private

  def authenticator
    if authenticator_name
      @authenticator ||= @authenticator_finder.find_authenticator(authenticator_name)
    end
  end

  def authenticator_name
    @auth_result&.authenticator_name
  end
end
