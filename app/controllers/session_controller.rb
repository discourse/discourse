require_dependency 'rate_limiter'
require_dependency 'single_sign_on'

class SessionController < ApplicationController

  skip_before_filter :redirect_to_login_if_required
  skip_before_filter :preload_json, :check_xhr, only: ['sso', 'sso_login', 'become', 'sso_provider', 'destroy']

  ACTIVATE_USER_KEY = "activate_user"

  def csrf
    render json: {csrf: form_authenticity_token }
  end

  def sso
    destination_url = cookies[:destination_url] || session[:destination_url]
    return_path = params[:return_path] || path('/')

    if destination_url && return_path == path('/')
      uri = URI::parse(destination_url)
      return_path = "#{uri.path}#{uri.query ? "?" << uri.query : ""}"
    end

    session.delete(:destination_url)
    cookies.delete(:destination_url)

    if SiteSetting.enable_sso?
      sso = DiscourseSingleSignOn.generate_sso(return_path)
      if SiteSetting.verbose_sso_logging
        Rails.logger.warn("Verbose SSO log: Started SSO process\n\n#{sso.diagnostics}")
      end
      redirect_to sso.to_url
    else
      render nothing: true, status: 404
    end
  end

  def sso_provider(payload=nil)
    payload ||= request.query_string
    if SiteSetting.enable_sso_provider
      sso = SingleSignOn.parse(payload, SiteSetting.sso_secret)
      if current_user
        sso.name = current_user.name
        sso.username = current_user.username
        sso.email = current_user.email
        sso.external_id = current_user.id.to_s
        sso.admin = current_user.admin?
        sso.moderator = current_user.moderator?

        if sso.return_sso_url.blank?
          render plain: "return_sso_url is blank, it must be provided", status: 400
          return
        end

        if request.xhr?
          cookies[:sso_destination_url] = sso.to_url(sso.return_sso_url)
        else
          redirect_to sso.to_url(sso.return_sso_url)
        end
      else
        session[:sso_payload] = request.query_string
        redirect_to path('/login')
      end
    else
      render nothing: true, status: 404
    end
  end

  # For use in development mode only when login options could be limited or disabled.
  # NEVER allow this to work in production.
  def become
    raise Discourse::InvalidAccess.new unless Rails.env.development?
    user = User.find_by_username(params[:session_id])
    raise "User #{params[:session_id]} not found" if user.blank?

    log_on_user(user)
    redirect_to path("/")
  end

  def sso_login
    raise Discourse::NotFound.new unless SiteSetting.enable_sso

    sso = DiscourseSingleSignOn.parse(request.query_string)
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
          redirect_to users_account_created_path and return
        else
          if SiteSetting.verbose_sso_logging
            Rails.logger.warn("Verbose SSO log: User was logged on #{user.username}\n\n#{sso.diagnostics}")
          end
          log_on_user user
        end

        # If it's not a relative URL check the host
        if return_path !~ /^\/[^\/]/
          begin
            uri = URI(return_path)
            return_path = path("/") unless SiteSetting.sso_allows_all_return_paths || uri.host == Discourse.current_hostname
          rescue
            return_path = path("/")
          end
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
      message = "Failed to create or lookup user: #{e}."
      message << "\n\n" << "-" * 100 << "\n\n"
      message << sso.diagnostics
      message << "\n\n" << "-" * 100 << "\n\n"
      message << e.backtrace.join("\n")

      Rails.logger.error(message)

      render_sso_error(text: I18n.t("sso.unknown_error"), status: 500)
    end
  end

  def create

    unless allow_local_auth?
      render nothing: true, status: 500
      return
    end

    RateLimiter.new(nil, "login-hr-#{request.remote_ip}", SiteSetting.max_logins_per_ip_per_hour, 1.hour).performed!
    RateLimiter.new(nil, "login-min-#{request.remote_ip}", SiteSetting.max_logins_per_ip_per_minute, 1.minute).performed!

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
        login_not_approved
        return
      end

      # User signed on with username and password, so let's prevent the invite link
      # from being used to log in (if one exists).
      Invite.invalidate_for_email(user.email)
    else
      invalid_credentials
      return
    end

    if user.suspended?
      failed_to_login(user)
      return
    end

    if ScreenedIpAddress.should_block?(request.remote_ip)
      return not_allowed_from_ip_address(user)
    end

    if ScreenedIpAddress.block_admin_login?(user, request.remote_ip)
      return admin_not_allowed_from_ip_address(user)
    end

    (user.active && user.email_confirmed?) ? login(user) : not_activated(user)
  end

  def forgot_password
    params.require(:login)

    unless allow_local_auth?
      render nothing: true, status: 500
      return
    end

    RateLimiter.new(nil, "forgot-password-hr-#{request.remote_ip}", 6, 1.hour).performed!
    RateLimiter.new(nil, "forgot-password-min-#{request.remote_ip}", 3, 1.minute).performed!

    RateLimiter.new(nil, "forgot-password-login-hour-#{params[:login].to_s[0..100]}", 12, 1.hour).performed!
    RateLimiter.new(nil, "forgot-password-login-min-#{params[:login].to_s[0..100]}", 3, 1.minute).performed!

    user = User.find_by_username_or_email(params[:login])
    user_presence = user.present? && user.id > 0 && !user.staged
    if user_presence
      email_token = user.email_tokens.create(email: user.email)
      Jobs.enqueue(:critical_user_email, type: :forgot_password, user_id: user.id, email_token: email_token.token)
    end

    json = { result: "ok" }
    unless SiteSetting.forgot_password_strict
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
      render nothing: true, status: 404
    end
  end

  def destroy
    reset_session
    log_off_user
    if request.xhr?
      render nothing: true
    else
      redirect_to (params[:return_url] || path("/"))
    end
  end

  private

  def allow_local_auth?
    !SiteSetting.enable_sso && SiteSetting.enable_local_logins
  end

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
    session[ACTIVATE_USER_KEY] = user.id
    render json: {
      error: I18n.t("login.not_activated"),
      reason: 'not_activated',
      sent_to_email: user.find_email || user.email,
      current_email: user.email
    }
  end

  def not_allowed_from_ip_address(user)
    render json: {error: I18n.t("login.not_allowed_from_ip_address", username: user.username)}
  end

  def admin_not_allowed_from_ip_address(user)
    render json: {error: I18n.t("login.admin_not_allowed_from_ip_address", username: user.username)}
  end

  def failed_to_login(user)
    message = user.suspend_reason ? "login.suspended_with_reason" : "login.suspended"

    render json: {
      error: I18n.t(message, { date: I18n.l(user.suspended_till, format: :date_only),
                               reason: Rack::Utils.escape_html(user.suspend_reason) }),
      reason: 'suspended'
    }
  end

  def login(user)
    session.delete(ACTIVATE_USER_KEY)
    log_on_user(user)

    if payload = session.delete(:sso_payload)
      sso_provider(payload)
    end
    render_serialized(user, UserSerializer)
  end


  def render_sso_error(status:, text:)
    @sso_error = text
    render status: status, layout: 'no_ember'
  end
end
