require_dependency 'rate_limiter'
require_dependency 'email_validator'
require_dependency 'email_updater'

class UsersEmailController < ApplicationController

  requires_login only: [:index, :update]

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

    token = EmailToken.confirmable(params[:token])
    user = token&.user

    change_request =
      if user
        user.email_change_requests.where(new_email_token_id: token.id).first
      end

    if change_request&.change_state == EmailChangeRequest.states[:authorizing_new] &&
       user.totp_enabled? && !user.authenticate_second_factor(params[:second_factor_token], params[:second_factor_method].to_i)

      @update_result = :invalid_second_factor
      @backup_codes_enabled = true if user.backup_codes_enabled?

      if params[:second_factor_token].present?
        RateLimiter.new(nil, "second-factor-min-#{request.remote_ip}", 3, 1.minute).performed!
        @show_invalid_second_factor_error = true
      end
    else
      updater = EmailUpdater.new
      @update_result = updater.confirm(params[:token])

      if @update_result == :complete
        updater.user.user_stat.reset_bounce_score!
        log_on_user(updater.user)
      end
    end

    render layout: 'no_ember'
  end

end
