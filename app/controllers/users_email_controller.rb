require_dependency 'rate_limiter'
require_dependency 'email_validator'

class UsersEmailController < ApplicationController

  before_filter :ensure_logged_in

  def index
  end

  def update
    params.require(:email)
    user = fetch_user_from_params
    guardian.ensure_can_edit_email!(user)
    lower_email = Email.downcase(params[:email]).strip

    RateLimiter.new(user, "change-email-hr-#{request.remote_ip}", 6, 1.hour).performed!
    RateLimiter.new(user, "change-email-min-#{request.remote_ip}", 3, 1.minute).performed!

    EmailValidator.new(attributes: :email).validate_each(user, :email, lower_email)
    return render_json_error(user.errors.full_messages) if user.errors[:email].present?

    # Raise an error if the email is already in use
    return render_json_error(I18n.t('change_email.error')) if User.find_by_email(lower_email)

    email_token = user.email_tokens.create(email: lower_email)
    Jobs.enqueue(
      :user_email,
      to_address: lower_email,
      type: :authorize_email,
      user_id: user.id,
      email_token: email_token.token
    )

    render nothing: true
  rescue RateLimiter::LimitExceeded
    render_json_error(I18n.t("rate_limiter.slow_down"))
  end

end

