class SessionController < ApplicationController

  skip_before_filter :redirect_to_login_if_required

  def csrf
    render json: {csrf: form_authenticity_token }
  end

  def create
    params.require(:login)
    params.require(:password)

    login = params[:login].strip
    login = login[1..-1] if login[0] == "@"

    if user = User.find_by_username_or_email(login)

      # If their password is correct
      unless user.confirm_password?(params[:password])
        invalid_credentials
        return
      end

      # If the site requires user approval and the user is not approved yet
      if login_not_approved_for?(user)
        login_not_approved
        return
      end

    else
      invalid_credentials
      return
    end

    if user.suspended?
      failed_to_login(user)
      return
    end

    user.email_confirmed? ? login(user) : not_activated(user)
  end

  def forgot_password
    params.require(:login)

    user = User.find_by_username_or_email(params[:login])
    if user.present?
      email_token = user.email_tokens.create(email: user.email)
      Jobs.enqueue(:user_email, type: :forgot_password, user_id: user.id, email_token: email_token.token)
    end
    # always render of so we don't leak information
    render json: {result: "ok"}
  end

  def destroy
    reset_session
    log_off_user
    render nothing: true
  end

  private

  def login_not_approved_for?(user)
    SiteSetting.must_approve_users? && !user.approved? && !user.admin?
  end

  def invalid_credentials
    render json: {error: I18n.t("login.incorrect_username_email_or_password")}
  end

  def login_not_approved
    render json: {error: I18n.t("login.not_approved")}
  end

  def not_activated(user)
    render json: {
      error: I18n.t("login.not_activated"),
      reason: 'not_activated',
      sent_to_email: user.find_email || user.email,
      current_email: user.email
    }
  end

  def failed_to_login(user)
    message = user.suspend_reason ? "login.suspended_with_reason" : "login.suspended"

    render json: { error: I18n.t(message, { date: I18n.l(user.suspended_till, format: :date_only),
                                            reason: user.suspend_reason}) }
  end

  def login(user)
    log_on_user(user)
    render_serialized(user, UserSerializer)
  end

end
