# frozen_string_literal: true

require_dependency 'rate_limiter'
require_dependency 'single_sign_on'
require_dependency 'single_sign_on_provider'
require_dependency 'url_helper'

class SessionController < ApplicationController
  class LocalLoginNotAllowed < StandardError; end
  rescue_from LocalLoginNotAllowed do
    render body: nil, status: 500
  end

  before_action :check_local_login_allowed, only: %i(create forgot_password email_login email_login_info)
  before_action :rate_limit_login, only: %i(create email_login)
  skip_before_action :redirect_to_login_if_required
  skip_before_action :preload_json, :check_xhr, only: %i(sso sso_login sso_provider destroy one_time_password)

  ACTIVATE_USER_KEY = "activate_user"

  def csrf
    render json: { csrf: form_authenticity_token }
  end

  def sso
    destination_url = cookies[:destination_url] || session[:destination_url]
    return_path = params[:return_path] || path('/')

    if destination_url && return_path == path('/')
      uri = URI::parse(destination_url)
      return_path = "#{uri.path}#{uri.query ? "?#{uri.query}" : ""}"
    end

    session.delete(:destination_url)
    cookies.delete(:destination_url)

    if SiteSetting.enable_sso?
      sso = DiscourseSingleSignOn.generate_sso(return_path)
      if SiteSetting.verbose_sso_logging
        Rails.logger.warn("Verbose SSO log: Started SSO process\n\n#{sso.diagnostics}")
      end
      redirect_to sso_url(sso)
    else
      render body: nil, status: 404
    end
  end

  def sso_provider(payload = nil)
    payload ||= request.query_string

    if SiteSetting.enable_sso_provider
      begin
        sso = SingleSignOnProvider.parse(payload)
      rescue SingleSignOnProvider::BlankSecret
        render plain: I18n.t("sso.missing_secret"), status: 400
        return
      end

      if sso.return_sso_url.blank?
        render plain: "return_sso_url is blank, it must be provided", status: 400
        return
      end

      if current_user
        sso.name = current_user.name
        sso.username = current_user.username
        sso.email = current_user.email
        sso.external_id = current_user.id.to_s
        sso.admin = current_user.admin?
        sso.moderator = current_user.moderator?
        sso.groups = current_user.groups.pluck(:name).join(",")

        if current_user.uploaded_avatar.present?
          base_url = Discourse.store.external? ? "#{Discourse.store.absolute_base_url}/" : Discourse.base_url
          avatar_url = "#{base_url}#{Discourse.store.get_path_for_upload(current_user.uploaded_avatar)}"
          sso.avatar_url = UrlHelper.absolute Discourse.store.cdn_url(avatar_url)
        end

        if current_user.user_profile.profile_background_upload.present?
          sso.profile_background_url = UrlHelper.absolute(upload_cdn_path(
            current_user.user_profile.profile_background_upload.url
          ))
        end

        if current_user.user_profile.card_background_upload.present?
          sso.card_background_url = UrlHelper.absolute(upload_cdn_path(
            current_user.user_profile.card_background_upload.url
          ))
        end

        if request.xhr?
          cookies[:sso_destination_url] = sso.to_url(sso.return_sso_url)
        else
          redirect_to sso.to_url(sso.return_sso_url)
        end
      else
        cookies[:sso_payload] = request.query_string
        redirect_to path('/login')
      end
    else
      render body: nil, status: 404
    end
  end

  # For use in development mode only when login options could be limited or disabled.
  # NEVER allow this to work in production.
  if !Rails.env.production?
    skip_before_action :check_xhr, only: [:become]

    def become

      raise Discourse::InvalidAccess if Rails.env.production?

      if ENV['DISCOURSE_DEV_ALLOW_ANON_TO_IMPERSONATE'] != "1"
        render(content_type: 'text/plain', inline: <<~TEXT)
          To enable impersonating any user without typing passwords set the following ENV var

          export DISCOURSE_DEV_ALLOW_ANON_TO_IMPERSONATE=1

          You can do that in your bashrc of bash profile file or the script you use to launch the web server
        TEXT

        return
      end

      user = User.find_by_username(params[:session_id])
      raise "User #{params[:session_id]} not found" if user.blank?

      log_on_user(user)
      redirect_to path("/")
    end
  end

  def sso_login
    raise Discourse::NotFound.new unless SiteSetting.enable_sso

    params.require(:sso)
    params.require(:sig)

    begin
      sso = DiscourseSingleSignOn.parse(request.query_string)
    rescue DiscourseSingleSignOn::ParseError => e
      if SiteSetting.verbose_sso_logging
        Rails.logger.warn("Verbose SSO log: Signature parse error\n\n#{e.message}\n\n#{sso&.diagnostics}")
      end

      # Do NOT pass the error text to the client, it would give them the correct signature
      return render_sso_error(text: I18n.t("sso.login_error"), status: 422)
    end

    if !sso.nonce_valid?
      if SiteSetting.verbose_sso_logging
        Rails.logger.warn("Verbose SSO log: Nonce has already expired\n\n#{sso.diagnostics}")
      end
      return render_sso_error(text: I18n.t("sso.timeout_expired"), status: 419)
    end

    if ScreenedIpAddress.should_block?(request.remote_ip)
      if SiteSetting.verbose_sso_logging
        Rails.logger.warn("Verbose SSO log: IP address is blocked #{request.remote_ip}\n\n#{sso.diagnostics}")
      end
      return render_sso_error(text: I18n.t("sso.unknown_error"), status: 500)
    end

    return_path = sso.return_path
    sso.expire_nonce!

    begin
      if user = sso.lookup_or_create_user(request.remote_ip)

        if user.suspended?
          render_sso_error(text: failed_to_login(user)[:error], status: 403)
          return
        end

        if SiteSetting.must_approve_users? && !user.approved?
          if SiteSetting.sso_not_approved_url.present?
            redirect_to SiteSetting.sso_not_approved_url
          else
            render_sso_error(text: I18n.t("sso.account_not_approved"), status: 403)
          end
          return
        elsif !user.active?
          activation = UserActivator.new(user, request, session, cookies)
          activation.finish
          session["user_created_message"] = activation.message
          redirect_to(users_account_created_path) && (return)
        else
          if SiteSetting.verbose_sso_logging
            Rails.logger.warn("Verbose SSO log: User was logged on #{user.username}\n\n#{sso.diagnostics}")
          end
          if user.id != current_user&.id
            log_on_user user
          end
        end

        # If it's not a relative URL check the host
        if return_path !~ /^\/[^\/]/
          begin
            uri = URI(return_path)
            if (uri.hostname == Discourse.current_hostname)
              return_path = uri.to_s
            elsif !SiteSetting.sso_allows_all_return_paths
              return_path = path("/")
            end
          rescue
            return_path = path("/")
          end
        end

        # this can be done more surgically with a regex
        # but it the edge case of never supporting redirects back to
        # any url with `/session/sso` in it anywhere is reasonable
        if return_path.include?(path("/session/sso"))
          return_path = path("/")
        end

        redirect_to return_path
      else
        render_sso_error(text: I18n.t("sso.not_found"), status: 500)
      end
    rescue ActiveRecord::RecordInvalid => e

      if SiteSetting.verbose_sso_logging
        Rails.logger.warn(<<~EOF)
        Verbose SSO log: Record was invalid: #{e.record.class.name} #{e.record.id}
        #{e.record.errors.to_h}

        Attributes:
        #{e.record.attributes.slice(*SingleSignOn::ACCESSORS.map(&:to_s))}

        SSO Diagnostics:
        #{sso.diagnostics}
        EOF
      end

      text = nil

      # If there's a problem with the email we can explain that
      if (e.record.is_a?(User) && e.record.errors[:email].present?)
        if e.record.email.blank?
          text = I18n.t("sso.no_email")
        else
          text = I18n.t("sso.email_error", email: ERB::Util.html_escape(e.record.email))
        end
      end

      render_sso_error(text: text || I18n.t("sso.unknown_error"), status: 500)

    rescue => e
      message = +"Failed to create or lookup user: #{e}."
      message << "  "
      message << "  #{sso.diagnostics}"
      message << "  "
      message << "  #{e.backtrace.join("\n")}"

      Rails.logger.error(message)

      render_sso_error(text: I18n.t("sso.unknown_error"), status: 500)
    end
  end

  def create
    unless params[:second_factor_token].blank?
      RateLimiter.new(nil, "second-factor-min-#{request.remote_ip}", 3, 1.minute).performed!
    end

    params.require(:login)
    params.require(:password)

    return invalid_credentials if params[:password].length > User.max_password_length

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
        render json: login_not_approved
        return
      end

      # User signed on with username and password, so let's prevent the invite link
      # from being used to log in (if one exists).
      Invite.invalidate_for_email(user.email)
    else
      invalid_credentials
      return
    end

    if payload = login_error_check(user)
      render json: payload
    else
      if user.totp_enabled? && !user.authenticate_second_factor(params[:second_factor_token], params[:second_factor_method].to_i)
        return render json: failed_json.merge(
          error: I18n.t("login.invalid_second_factor_code"),
          reason: "invalid_second_factor",
          backup_enabled: user.backup_codes_enabled?
        )
      end

      (user.active && user.email_confirmed?) ? login(user) : not_activated(user)
    end
  end

  def email_login_info
    raise Discourse::NotFound if !SiteSetting.enable_local_logins_via_email

    token = params[:token]
    matched_token = EmailToken.confirmable(token)

    if matched_token
      response = {
        can_login: true,
        token: token,
        token_email: matched_token.email
      }

      if matched_token.user&.totp_enabled?
        response.merge!(
          second_factor_required: true,
          backup_codes_enabled: matched_token.user&.backup_codes_enabled?
        )
      end

      render json: response
    else
      render json: {
        can_login: false,
        error: I18n.t('email_login.invalid_token')
      }
    end
  end

  def email_login
    raise Discourse::NotFound if !SiteSetting.enable_local_logins_via_email
    second_factor_token = params[:second_factor_token]
    second_factor_method = params[:second_factor_method].to_i
    token = params[:token]
    matched_token = EmailToken.confirmable(token)

    if matched_token&.user&.totp_enabled?
      if !second_factor_token.present?
        return render json: { error: I18n.t('login.invalid_second_factor_code') }
      elsif !matched_token.user.authenticate_second_factor(second_factor_token, second_factor_method)
        RateLimiter.new(nil, "second-factor-min-#{request.remote_ip}", 3, 1.minute).performed!
        return render json: { error: I18n.t('login.invalid_second_factor_code') }
      end
    end

    if user = EmailToken.confirm(token)
      if login_not_approved_for?(user)
        return render json: login_not_approved
      elsif payload = login_error_check(user)
        return render json: payload
      else
        log_on_user(user)
        return render json: success_json
      end
    end

    return render json: { error: I18n.t('email_login.invalid_token') }
  end

  def one_time_password
    @otp_username = otp_username = $redis.get "otp_#{params[:token]}"

    if otp_username && user = User.find_by_username(otp_username)
      if current_user&.username == otp_username
        $redis.del "otp_#{params[:token]}"
        return redirect_to path("/")
      elsif request.post?
        log_on_user(user)
        $redis.del "otp_#{params[:token]}"
        return redirect_to path("/")
      else
        # Display the form
      end
    else
      @error = I18n.t('user_api_key.invalid_token')
    end

    render layout: 'no_ember', locals: { hide_auth_buttons: true }
  end

  def forgot_password
    params.require(:login)

    RateLimiter.new(nil, "forgot-password-hr-#{request.remote_ip}", 6, 1.hour).performed!
    RateLimiter.new(nil, "forgot-password-min-#{request.remote_ip}", 3, 1.minute).performed!

    RateLimiter.new(nil, "forgot-password-login-hour-#{params[:login].to_s[0..100]}", 12, 1.hour).performed!
    RateLimiter.new(nil, "forgot-password-login-min-#{params[:login].to_s[0..100]}", 3, 1.minute).performed!

    user = User.find_by_username_or_email(params[:login])
    user_presence = user.present? && user.human? && !user.staged
    if user_presence
      email_token = user.email_tokens.create(email: user.email)
      Jobs.enqueue(:critical_user_email, type: :forgot_password, user_id: user.id, email_token: email_token.token)
    end

    json = success_json
    unless SiteSetting.hide_email_address_taken
      json[:user_found] = user_presence
    end

    render json: json

  rescue RateLimiter::LimitExceeded
    render_json_error(I18n.t("rate_limiter.slow_down"))
  end

  def current
    if current_user.present?
      render_serialized(current_user, CurrentUserSerializer)
    else
      render body: nil, status: 404
    end
  end

  def destroy
    reset_session
    log_off_user
    if request.xhr?
      render body: nil
    else
      redirect_to (params[:return_url] || path("/"))
    end
  end

  protected

  def check_local_login_allowed
    if SiteSetting.enable_sso || !SiteSetting.enable_local_logins
      raise LocalLoginNotAllowed, "SSO takes over local login or the local login is disallowed."
    end
  end

  private

  def login_error_check(user)
    return failed_to_login(user) if user.suspended?

    if ScreenedIpAddress.should_block?(request.remote_ip)
      return not_allowed_from_ip_address(user)
    end

    if ScreenedIpAddress.block_admin_login?(user, request.remote_ip)
      return admin_not_allowed_from_ip_address(user)
    end
  end

  def login_not_approved_for?(user)
    SiteSetting.must_approve_users? && !user.approved? && !user.admin?
  end

  def invalid_credentials
    render json: { error: I18n.t("login.incorrect_username_email_or_password") }
  end

  def login_not_approved
    { error: I18n.t("login.not_approved") }
  end

  def not_activated(user)
    session[ACTIVATE_USER_KEY] = user.id
    render json: {
      error: I18n.t("login.not_activated"),
      reason: 'not_activated',
      sent_to_email: user.find_email || user.email,
      current_email: user.email
    }
  end

  def not_allowed_from_ip_address(user)
    { error: I18n.t("login.not_allowed_from_ip_address", username: user.username) }
  end

  def admin_not_allowed_from_ip_address(user)
    { error: I18n.t("login.admin_not_allowed_from_ip_address", username: user.username) }
  end

  def failed_to_login(user)
    message = user.suspend_reason ? "login.suspended_with_reason" : "login.suspended"

    {
      error: I18n.t(message,
        date: I18n.l(user.suspended_till, format: :date_only),
        reason: Rack::Utils.escape_html(user.suspend_reason)
      ),
      reason: 'suspended'
    }
  end

  def login(user)
    session.delete(ACTIVATE_USER_KEY)
    log_on_user(user)

    if payload = cookies.delete(:sso_payload)
      sso_provider(payload)
    else
      render_serialized(user, UserSerializer)
    end
  end

  def rate_limit_login
    RateLimiter.new(
      nil,
      "login-hr-#{request.remote_ip}",
      SiteSetting.max_logins_per_ip_per_hour,
      1.hour
    ).performed!

    RateLimiter.new(
      nil,
      "login-min-#{request.remote_ip}",
      SiteSetting.max_logins_per_ip_per_minute,
      1.minute
    ).performed!
  end

  def render_sso_error(status:, text:)
    @sso_error = text
    render status: status, layout: 'no_ember'
  end

  # extension to allow plugins to customize the SSO URL
  def sso_url(sso)
    sso.to_url
  end
end
