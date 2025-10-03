# frozen_string_literal: true

class UsersEmailController < ApplicationController
  requires_login only: %i[index update]

  skip_before_action :check_xhr, only: %i[show_confirm_old_email show_confirm_new_email]

  skip_before_action :redirect_to_login_if_required,
                     :redirect_to_profile_if_required,
                     only: %i[
                       show_confirm_old_email
                       show_confirm_new_email
                       confirm_old_email
                       confirm_new_email
                     ]

  def index
  end

  def create
    return render json: failed_json, status: 410 if !SiteSetting.enable_secondary_emails

    params.require(:email)
    user = fetch_user_from_params

    RateLimiter.new(user, "email-hr-#{request.remote_ip}", 6, 1.hour).performed!
    RateLimiter.new(user, "email-min-#{request.remote_ip}", 3, 1.minute).performed!

    updater = EmailUpdater.new(guardian: guardian, user: user)
    updater.change_to(params[:email], add: true)

    return render_json_error(updater.errors.full_messages) if updater.errors.present?

    render body: nil
  rescue RateLimiter::LimitExceeded
    render_json_error(I18n.t("rate_limiter.slow_down"))
  end

  def update
    params.require(:email)
    user = fetch_user_from_params

    RateLimiter.new(user, "email-hr-#{request.remote_ip}", 6, 1.hour).performed!
    RateLimiter.new(user, "email-min-#{request.remote_ip}", 3, 1.minute).performed!

    updater = EmailUpdater.new(guardian: guardian, user: user)
    updater.change_to(params[:email])

    return render_json_error(updater.errors.full_messages) if updater.errors.present?

    render body: nil
  rescue RateLimiter::LimitExceeded
    render_json_error(I18n.t("rate_limiter.slow_down"))
  end

  def confirm_new_email
    change_request = load_change_request(:new)

    result =
      run_second_factor!(SecondFactor::Actions::ConfirmEmail, target_user: change_request.user)

    if result.no_second_factors_enabled? || result.second_factor_auth_completed?
      updater = EmailUpdater.new
      if updater.confirm(params[:token]) == :complete
        updater.user.user_stat.reset_bounce_score!
        render json: success_json
      else
        render json: { error: I18n.t("change_email.already_done") }, status: 400
      end
    end
  end

  def show_confirm_new_email
    return render "default/empty" if request.format.html?

    change_request = load_change_request(:new)

    render json: {
             new_email: change_request.new_email,
             old_email: change_request.old_email,
             token: params[:token],
           }
  end

  def confirm_old_email
    load_change_request(:old)

    updater = EmailUpdater.new
    if updater.confirm(params[:token]) == :authorizing_new
      render json: success_json
    else
      render json: { error: I18n.t("change_email.already_done") }, status: 400
    end
  end

  def show_confirm_old_email
    return render "default/empty" if request.format.html?

    change_request = load_change_request(:old)

    render json: {
             new_email: change_request.new_email,
             old_email: change_request.old_email,
             token: params[:token],
           }
  end

  private

  def load_change_request(type)
    expires_now

    token = EmailToken.confirmable(params[:token], scope: EmailToken.scopes[:email_update])

    raise Discourse::NotFound if !token || !token.user

    if current_user && token.user.id != current_user.id
      raise Discourse::InvalidAccess.new "You are logged in, but this email change link belongs to another user account. Please log out and try again."
    end

    change_request_params =
      if type == :old
        { old_email_token_id: token.id, change_state: EmailChangeRequest.states[:authorizing_old] }
      elsif type == :new
        { new_email_token_id: token.id, change_state: EmailChangeRequest.states[:authorizing_new] }
      end

    token.user&.email_change_requests&.find_by!(**change_request_params)
  end
end
