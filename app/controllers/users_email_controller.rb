# frozen_string_literal: true

class UsersEmailController < ApplicationController

  requires_login only: [:index, :update]

  skip_before_action :check_xhr, only: [
    :confirm_old_email,
    :show_confirm_old_email,
    :confirm_new_email,
    :show_confirm_new_email
  ]

  skip_before_action :redirect_to_login_if_required, only: [
    :confirm_old_email,
    :show_confirm_old_email,
    :confirm_new_email,
    :show_confirm_new_email
  ]

  before_action :require_login, only: [
    :confirm_old_email,
    :show_confirm_old_email
  ]

  def index
  end

  def create
    if !SiteSetting.enable_secondary_emails
      return render json: failed_json, status: 410
    end

    params.require(:email)
    user = fetch_user_from_params

    RateLimiter.new(user, "email-hr-#{request.remote_ip}", 6, 1.hour).performed!
    RateLimiter.new(user, "email-min-#{request.remote_ip}", 3, 1.minute).performed!

    updater = EmailUpdater.new(guardian: guardian, user: user)
    updater.change_to(params[:email], add: true)

    if updater.errors.present?
      return render_json_error(updater.errors.full_messages)
    end

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

    if updater.errors.present?
      return render_json_error(updater.errors.full_messages)
    end

    render body: nil
  rescue RateLimiter::LimitExceeded
    render_json_error(I18n.t("rate_limiter.slow_down"))
  end

  def confirm_new_email
    load_change_request(:new)

    if @change_request&.change_state != EmailChangeRequest.states[:authorizing_new]
      @error = I18n.t("change_email.already_done")
    end

    redirect_url = path("/u/confirm-new-email/#{params[:token]}")

    rate_limit_second_factor!(@user)

    if !@error
      # this is needed because the form posts this field as JSON and it can be a
      # hash when authenticating security key.
      if params[:second_factor_method].to_i == UserSecondFactor.methods[:security_key]
        begin
          params[:second_factor_token] = JSON.parse(params[:second_factor_token])
        rescue JSON::ParserError
          raise Discourse::InvalidParameters
        end
      end

      second_factor_authentication_result = @user.authenticate_second_factor(params, secure_session)
      if !second_factor_authentication_result.ok
        flash[:invalid_second_factor] = true
        flash[:invalid_second_factor_message] = second_factor_authentication_result.error
        redirect_to redirect_url
        return
      end
    end

    if !@error
      updater = EmailUpdater.new
      if updater.confirm(params[:token]) == :complete
        updater.user.user_stat.reset_bounce_score!
      else
        @error = I18n.t("change_email.already_done")
      end
    end

    if @error
      flash[:error] = @error
      redirect_to redirect_url
    else
      redirect_to "#{redirect_url}?done=true"
    end
  end

  def show_confirm_new_email
    load_change_request(:new)

    if params[:done].to_s == "true"
      @done = true
    end

    if @change_request&.change_state != EmailChangeRequest.states[:authorizing_new]
      @error = I18n.t("change_email.already_done")
    end

    @show_invalid_second_factor_error = flash[:invalid_second_factor]
    @invalid_second_factor_message = flash[:invalid_second_factor_message]

    if !@error
      @backup_codes_enabled = @user.backup_codes_enabled?
      if params[:show_backup].to_s == "true" && @backup_codes_enabled
        @show_backup_codes = true
      else
        if @user.totp_enabled?
          @show_second_factor = true
        end
        if @user.security_keys_enabled?
          Webauthn.stage_challenge(@user, secure_session)
          @show_security_key = params[:show_totp].to_s == "true" ? false : true
          @security_key_challenge = Webauthn.challenge(@user, secure_session)
          @security_key_allowed_credential_ids = Webauthn.allowed_credentials(@user, secure_session)[:allowed_credential_ids]
        end
      end

      @to_email = @change_request.new_email
    end

    render layout: 'no_ember'
  end

  def confirm_old_email
    load_change_request(:old)

    if @change_request&.change_state != EmailChangeRequest.states[:authorizing_old]
      @error = I18n.t("change_email.already_done")
    end

    redirect_url = path("/u/confirm-old-email/#{params[:token]}")

    if !@error
      updater = EmailUpdater.new
      if updater.confirm(params[:token]) != :authorizing_new
        @error = I18n.t("change_email.already_done")
      end
    end

    if @error
      flash[:error] = @error
      redirect_to redirect_url
    else
      redirect_to "#{redirect_url}?done=true"
    end
  end

  def show_confirm_old_email
    load_change_request(:old)

    if @change_request&.change_state != EmailChangeRequest.states[:authorizing_old]
      @error = I18n.t("change_email.already_done")
    end

    if params[:done].to_s == "true"
      @almost_done = true
    end

    if !@error
      @from_email = @user.email
      @to_email = @change_request.new_email
    end

    render layout: 'no_ember'
  end

  private

  def load_change_request(type)
    expires_now

    token = EmailToken.confirmable(params[:token], scope: EmailToken.scopes[:email_update])

    if token
      if type == :old
        @change_request = token.user&.email_change_requests.where(old_email_token_id: token.id).first
      elsif type == :new
        @change_request = token.user&.email_change_requests.where(new_email_token_id: token.id).first
      end
    end

    @user = token&.user

    if (!@user || !@change_request)
      @error = I18n.t("change_email.already_done")
    end

    if current_user && current_user.id != @user&.id
      @error = I18n.t 'change_email.wrong_account_error'
    end
  end

  def require_login
    if !current_user
      redirect_to_login
    end
  end

end
