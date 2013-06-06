class SessionController < ApplicationController
  # we need to allow account login with bad CSRF tokens, if people are caching, the CSRF token on the
  #  page is going to be empty, this means that server will see an invalid CSRF and blow the session
  #  once that happens you can't log in with social
  skip_before_filter :verify_authenticity_token, only: [:create]
  skip_before_filter :redirect_to_login_if_required

  def create
    params.require(:login)
    params.require(:password)

    login = params[:login]
    login = login[1..-1] if login[0] == "@"

    if login =~ /@/
      @user = User.where(email: Email.downcase(login)).first
    else
      @user = User.where(username_lower: login.downcase).first
    end

    if @user.present?

      # If the site requires user approval and the user is not approved yet
      if SiteSetting.must_approve_users? && !@user.approved?
        render json: {error: I18n.t("login.not_approved")}
        return
      end

      # If their password is correct
      if @user.confirm_password?(params[:password])
        if @user.email_confirmed?
          log_on_user(@user)
          render_serialized(@user, UserSerializer)
          return
        else
          render json: {
            error: I18n.t("login.not_activated"),
            reason: 'not_activated',
            sent_to_email: @user.email_logs.where(email_type: 'signup').order('created_at DESC').first.try(:to_address) || @user.email,
            current_email: @user.email
          }
          return
        end
      end
    end

    render json: {error: I18n.t("login.incorrect_username_email_or_password")}
  end

  def forgot_password
    params.require(:login)

    user = User.where('username_lower = :username or email = :email', username: params[:login].downcase, email: Email.downcase(params[:login])).first
    if user.present?
      email_token = user.email_tokens.create(email: user.email)
      Jobs.enqueue(:user_email, type: :forgot_password, user_id: user.id, email_token: email_token.token)
    end
    # always render of so we don't leak information
    render json: {result: "ok"}
  end

  def destroy
    session[:current_user_id] = nil
    cookies[:_t] = nil
    render nothing: true
  end

end
