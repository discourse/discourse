require_dependency 'rate_limiter'
require_dependency 'email_validator'
require_dependency 'email_updater'

class UsersEmailController < ApplicationController

  before_action :ensure_logged_in, only: [:index, :update]

  skip_before_action :check_xhr, only: [:confirm]
  skip_before_action :redirect_to_login_if_required, only: [:confirm]

  def index
  end

  def update
    params.require(:email)
    user = fetch_user_from_params

    RateLimiter.new(user, "change-email-hr-#{request.remote_ip}", 6, 1.hour).performed!
    RateLimiter.new(user, "change-email-min-#{request.remote_ip}", 3, 1.minute).performed!

    updater = EmailUpdater.new(guardian, user)
    updater.change_to(params[:email])

    if updater.errors.present?
      return render_json_error(updater.errors.full_messages)
    end

    render body: nil
  rescue RateLimiter::LimitExceeded
    render_json_error(I18n.t("rate_limiter.slow_down"))
  end

  def confirm
    expires_now
    updater = EmailUpdater.new
    @update_result = updater.confirm(params[:token])

    if @update_result == :complete
      updater.user.user_stat.reset_bounce_score!
      log_on_user(updater.user)
    end

    render layout: 'no_ember'
  end

end
