# frozen_string_literal: true

class SessionController < ApplicationController
  before_action :check_local_login_allowed,
                only: %i[create forgot_password passkey_challenge passkey_login]
  before_action :rate_limit_login, only: %i[create email_login]
  skip_before_action :redirect_to_login_if_required
  skip_before_action :redirect_to_profile_if_required
  skip_before_action :preload_json,
                     :check_xhr,
                     only: %i[sso sso_login sso_provider destroy one_time_password]

  skip_before_action :check_xhr, only: %i[second_factor_auth_show]

  allow_in_staff_writes_only_mode :create, :email_login, :forgot_password

  ACTIVATE_USER_KEY = "activate_user"
  FORGOT_PASSWORD_EMAIL_LIMIT_PER_DAY = 6

  def csrf
    render json: { csrf: form_authenticity_token }
  end

  def sso
    raise Discourse::NotFound unless SiteSetting.enable_discourse_connect?

    destination_url = cookies[:destination_url] || session[:destination_url]
    return_path = params[:return_path] || path("/")

    if destination_url && return_path == path("/")
      uri = URI.parse(destination_url)
      return_path = "#{uri.path}#{uri.query ? "?#{uri.query}" : ""}"
    end

    session.delete(:destination_url)
    cookies.delete(:destination_url)

    sso = DiscourseConnect.generate_sso(return_path, secure_session: secure_session)
    connect_verbose_warn { "Verbose SSO log: Started SSO process\n\n#{sso.diagnostics}" }
    redirect_to sso_url(sso), allow_other_host: true
  end

  def sso_provider(payload = nil, confirmed_2fa_during_login = false)
    raise Discourse::NotFound unless SiteSetting.enable_discourse_connect_provider

    result =
      run_second_factor!(
        SecondFactor::Actions::DiscourseConnectProvider,
        action_data: {
          payload: payload,
          confirmed_2fa_during_login: confirmed_2fa_during_login,
        },
      )

    if result.second_factor_auth_skipped?
      data = result.data
      if data[:logout]
        params[:return_url] = data[:return_sso_url]
        destroy
        return
      end

      if data[:no_current_user]
        if data[:prompt] == "none"
          redirect_to data[:sso_redirect_url], allow_other_host: true
          return
        else
          cookies[:sso_payload] = payload || request.query_string
          redirect_to path("/login")
          return
        end
      end

      if request.xhr?
        # for the login modal
        cookies[:sso_destination_url] = data[:sso_redirect_url]
        render json: success_json.merge(redirect_url: data[:sso_redirect_url])
      else
        redirect_to data[:sso_redirect_url], allow_other_host: true
      end
    elsif result.no_second_factors_enabled?
      if request.xhr?
        # for the login modal
        cookies[:sso_destination_url] = result.data[:sso_redirect_url]
      else
        redirect_to result.data[:sso_redirect_url], allow_other_host: true
      end
    elsif result.second_factor_auth_completed?
      redirect_url = result.data[:sso_redirect_url]
      render json: success_json.merge(redirect_url: redirect_url)
    end
  rescue DiscourseConnectProvider::BlankSecret
    render plain: I18n.t("discourse_connect.missing_secret"), status: 400
  rescue DiscourseConnectProvider::ParseError
    # Do NOT pass the error text to the client, it would give them the correct signature
    render plain: I18n.t("discourse_connect.login_error"), status: 422
  rescue DiscourseConnectProvider::BlankReturnUrl
    render plain: "return_sso_url is blank, it must be provided", status: 400
  rescue DiscourseConnectProvider::InvalidParameterValueError => e
    render plain: I18n.t("discourse_connect.invalid_parameter_value", param: e.param), status: 400
  end

  # For use in development mode only when login options could be limited or disabled.
  # NEVER allow this to work in production.
  if !Rails.env.production?
    skip_before_action :check_xhr, only: [:become]

    def become
      raise Discourse::InvalidAccess if Rails.env.production?
      raise Discourse::ReadOnly if @readonly_mode

      if ENV["DISCOURSE_DEV_ALLOW_ANON_TO_IMPERSONATE"] != "1"
        render(content_type: "text/plain", inline: <<~TEXT)
          To enable impersonating any user without typing passwords set the following ENV var

          export DISCOURSE_DEV_ALLOW_ANON_TO_IMPERSONATE=1

          You can do that in your bashrc of bash profile file or the script you use to launch the web server
        TEXT

        return
      end

      user = User.find_by_username(params[:session_id])
      raise "User #{params[:session_id]} not found" if user.blank?

      log_on_user(user)

      if params[:redirect] == "false"
        render plain: "Signed in to #{params[:session_id]} successfully"
      else
        redirect_to path("/")
      end
    end
  end

  if Rails.env.test?
    skip_before_action :check_xhr, only: :test_second_factor_restricted_route

    def test_second_factor_restricted_route
      target_user = User.find_by_username(params[:username]) || current_user
      raise "user required" if !target_user
      result =
        run_second_factor!(TestSecondFactorAction, target_user: target_user) do |manager|
          manager.allow_backup_codes! if params[:allow_backup_codes]
        end
      if result.no_second_factors_enabled?
        render json: { result: "no_second_factors_enabled" }
      else
        render json: { result: "second_factor_auth_completed" }
      end
    rescue StandardError => e
      # Normally this would be checked by the consumer before calling `run_second_factor!`
      # but since this is a test route, we allow passing a bad value into the API, catch the error
      # and return a JSON response to assert against.
      if e.message == "running 2fa against another user is not allowed"
        render json: { result: "wrong user" }, status: 400
      else
        raise e
      end
    end
  end

  def sso_login
    raise Discourse::NotFound unless SiteSetting.enable_discourse_connect
    raise Discourse::ReadOnly if @readonly_mode && !staff_writes_only_mode?

    params.require(:sso)
    params.require(:sig)

    begin
      sso = DiscourseConnect.parse(request.query_string, secure_session: secure_session)
    rescue DiscourseConnect::PayloadParseError => e
      connect_verbose_warn do
        "Verbose SSO log: Payload is not base64\n\n#{e.message}\n\n#{sso&.diagnostics}"
      end

      return render_sso_error(text: I18n.t("discourse_connect.payload_parse_error"), status: 422)
    rescue DiscourseConnect::SignatureError => e
      connect_verbose_warn do
        "Verbose SSO log: Signature verification failed\n\n#{e.message}\n\n#{sso&.diagnostics}"
      end

      # Do NOT pass the error text to the client, it would give them the correct signature
      return render_sso_error(text: I18n.t("discourse_connect.signature_error"), status: 422)
    end

    if !sso.nonce_valid?
      connect_verbose_warn { "Verbose SSO log: #{sso.nonce_error}\n\n#{sso.diagnostics}" }
      return render_sso_error(text: I18n.t("discourse_connect.timeout_expired"), status: 419)
    end

    if ScreenedIpAddress.should_block?(request.remote_ip)
      connect_verbose_warn do
        "Verbose SSO log: IP address is blocked #{request.remote_ip}\n\n#{sso.diagnostics}"
      end
      return render_sso_error(text: I18n.t("discourse_connect.unknown_error"), status: 500)
    end

    return_path = sso.return_path
    sso.expire_nonce!

    begin
      invite = validate_invitiation!(sso)

      if user = sso.lookup_or_create_user(request.remote_ip)
        raise Discourse::ReadOnly if staff_writes_only_mode? && !user&.staff?

        if user.suspended?
          render_sso_error(text: failed_to_login(user)[:error], status: 403)
          return
        end

        if SiteSetting.must_approve_users? && !user.approved?
          redeem_invitation(invite, sso, user) if invite.present? && user.invited_user.blank?

          if SiteSetting.discourse_connect_not_approved_url.present?
            redirect_to SiteSetting.discourse_connect_not_approved_url, allow_other_host: true
          else
            render_sso_error(text: I18n.t("discourse_connect.account_not_approved"), status: 403)
          end
          return

          # we only want to redeem the invite if
          # the user has not already redeemed an invite
          # (covers the same SSO user visiting an invite link)
        elsif invite.present? && user.invited_user.blank?
          redeem_invitation(invite, sso, user)

          # we directly call user.activate here instead of going
          # through the UserActivator path because we assume the account
          # is valid from the SSO provider's POV and do not need to
          # send an activation email to the user
          user.activate
          login_sso_user(sso, user)

          topic = invite.topics.first
          return_path = topic.present? ? path(topic.relative_url) : path("/")
        elsif !user.active?
          activation = UserActivator.new(user, request, session, cookies)
          activation.finish
          session["user_created_message"] = activation.message
          return redirect_to(users_account_created_path)
        else
          login_sso_user(sso, user)
        end

        # If it's not a relative URL check the host
        if return_path !~ %r{\A/[^/]}
          begin
            uri = URI(return_path)
            if (uri.hostname == Discourse.current_hostname)
              return_path = uri.to_s
            elsif !domain_redirect_allowed?(uri.hostname)
              return_path = path("/")
            end
          rescue StandardError
            return_path = path("/")
          end
        end

        # this can be done more surgically with a regex
        # but it the edge case of never supporting redirects back to
        # any url with `/session/sso` in it anywhere is reasonable
        return_path = path("/") if return_path.include?(path("/session/sso"))

        redirect_to return_path, allow_other_host: true
      else
        render_sso_error(text: I18n.t("discourse_connect.not_found"), status: 500)
      end
    rescue ActiveRecord::RecordInvalid => e
      connect_verbose_warn { <<~TEXT }
        Verbose SSO log: Record was invalid: #{e.record.class.name} #{e.record.id}
        #{e.record.errors.to_h}

        Attributes:
        #{e.record.attributes.slice(*DiscourseConnectBase::ACCESSORS.map(&:to_s))}

        SSO Diagnostics:
        #{sso.diagnostics}
      TEXT

      text = nil

      # If there's a problem with the email we can explain that
      if (e.record.is_a?(User) && e.record.errors[:primary_email].present?)
        if e.record.email.blank?
          text = I18n.t("discourse_connect.no_email")
        else
          text =
            I18n.t("discourse_connect.email_error", email: ERB::Util.html_escape(e.record.email))
        end
      end

      render_sso_error(text: text || I18n.t("discourse_connect.unknown_error"), status: 500)
    rescue DiscourseConnect::BlankExternalId
      render_sso_error(text: I18n.t("discourse_connect.blank_id_error"), status: 500)
    rescue Invite::ValidationFailed => e
      render_sso_error(text: e.message, status: 400)
    rescue Invite::RedemptionFailed => e
      render_sso_error(text: I18n.t("discourse_connect.invite_redeem_failed"), status: 412)
    rescue Invite::UserExists => e
      render_sso_error(text: e.message, status: 412)
    rescue => e
      message = +"Failed to create or lookup user: #{e}."
      message << "  "
      message << "  #{sso.diagnostics}"
      message << "  "
      message << "  #{e.backtrace.join("\n")}"

      Rails.logger.error(message)

      render_sso_error(text: I18n.t("discourse_connect.unknown_error"), status: 500)
    end
  end

  def login_sso_user(sso, user)
    connect_verbose_warn do
      "Verbose SSO log: User was logged on #{user.username}\n\n#{sso.diagnostics}"
    end
    log_on_user(user) if user.id != current_user&.id
  end

  def create
    params.require(:login)
    params.require(:password)

    return invalid_credentials if params[:password].length > User.max_password_length

    user = User.find_by_username_or_email(normalized_login_param)

    raise Discourse::ReadOnly if staff_writes_only_mode? && !user&.staff?

    rate_limit_second_factor!(user)

    if user.present?
      password = params[:password]

      # If their password is incorrect
      if !user.confirm_password?(password)
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

      # User's password has expired so they need to reset it
      if user.password_expired?(password)
        render json: { error: "expired", reason: "expired" }
        return
      end
    else
      invalid_credentials
      return
    end

    if payload = login_error_check(user)
      return render json: payload
    end

    second_factor_auth_result = authenticate_second_factor(user)
    return render(json: @second_factor_failure_payload) if !second_factor_auth_result.ok

    if user.active && user.email_confirmed?
      login(user, second_factor_auth_result: second_factor_auth_result)
    else
      not_activated(user)
    end
  end

  def passkey_challenge
    render json: DiscourseWebauthn.stage_challenge(current_user, secure_session)
  end

  def passkey_login
    raise Discourse::NotFound unless SiteSetting.enable_passkeys

    params.require(:publicKeyCredential)

    security_key =
      ::DiscourseWebauthn::AuthenticationService.new(
        nil,
        params[:publicKeyCredential],
        session: secure_session,
        factor_type: UserSecurityKey.factor_types[:first_factor],
      ).authenticate_security_key

    user = User.where(id: security_key.user_id, active: true).first

    if user.email_confirmed?
      login(user, passkey_login: true)
    else
      not_activated(user)
    end
  rescue ::DiscourseWebauthn::SecurityKeyError => err
    render_json_error(err.message, status: 401)
  end

  def email_login_info
    token = params[:token]
    matched_token = EmailToken.confirmable(token, scope: EmailToken.scopes[:email_login])
    user = matched_token&.user

    check_local_login_allowed(user: user, check_login_via_email: true)

    if matched_token
      response = { can_login: true, token: token, token_email: matched_token.email }

      matched_user = matched_token.user
      if matched_user&.totp_enabled?
        response.merge!(
          second_factor_required: true,
          backup_codes_enabled: matched_user&.backup_codes_enabled?,
          totp_enabled: matched_user&.totp_enabled?,
        )
      end

      if matched_user&.security_keys_enabled?
        DiscourseWebauthn.stage_challenge(matched_user, secure_session)
        response.merge!(
          DiscourseWebauthn.allowed_credentials(matched_user, secure_session).merge(
            security_key_required: true,
          ),
        )
      end

      render json: response
    else
      render json: {
               can_login: false,
               error: I18n.t("email_login.invalid_token", base_url: Discourse.base_url),
             }
    end
  end

  def email_login
    token = params[:token]
    matched_token = EmailToken.confirmable(token, scope: EmailToken.scopes[:email_login])
    user = matched_token&.user

    check_local_login_allowed(user: user, check_login_via_email: true)

    rate_limit_second_factor!(user)

    if user.present? && !authenticate_second_factor(user).ok
      return render(json: @second_factor_failure_payload)
    end

    if user = EmailToken.confirm(token, scope: EmailToken.scopes[:email_login])
      if login_not_approved_for?(user)
        return render json: login_not_approved
      elsif payload = login_error_check(user)
        return render json: payload
      else
        raise Discourse::ReadOnly if staff_writes_only_mode? && !user&.staff?
        user.update_timezone_if_missing(params[:timezone])
        log_on_user(user)
        return render json: success_json
      end
    end

    render json: { error: I18n.t("email_login.invalid_token", base_url: Discourse.base_url) }
  end

  def one_time_password
    @otp_username = otp_username = Discourse.redis.get "otp_#{params[:token]}"

    if otp_username && user = User.find_by_username(otp_username)
      if current_user&.username == otp_username
        Discourse.redis.del "otp_#{params[:token]}"
        return redirect_to path("/")
      elsif request.post?
        log_on_user(user)
        Discourse.redis.del "otp_#{params[:token]}"
        return redirect_to path("/")
      else
        # Display the form
      end
    else
      @error = I18n.t("user_api_key.invalid_token")
    end

    render layout: "no_ember", locals: { hide_auth_buttons: true }
  end

  def second_factor_auth_show
    nonce = params.require(:nonce)
    challenge = nil
    error_key = nil
    user = nil
    status_code = 200
    begin
      challenge =
        SecondFactor::AuthManager.find_second_factor_challenge(
          nonce: nonce,
          secure_session: secure_session,
          target_user: current_user,
        )
    rescue SecondFactor::BadChallenge => exception
      error_key = exception.error_translation_key
      status_code = exception.status_code
    end

    json = {}
    if challenge
      user = User.find(challenge[:target_user_id])
      json.merge!(
        totp_enabled: user.totp_enabled?,
        backup_enabled: user.backup_codes_enabled?,
        allowed_methods: challenge[:allowed_methods],
      )
      if user.security_keys_enabled?
        DiscourseWebauthn.stage_challenge(user, secure_session)
        json.merge!(DiscourseWebauthn.allowed_credentials(user, secure_session))
        json[:security_keys_enabled] = true
      else
        json[:security_keys_enabled] = false
      end
      json[:description] = challenge[:description] if challenge[:description]
    else
      json[:error] = I18n.t(error_key)
    end

    respond_to do |format|
      format.html do
        store_preloaded("2fa_challenge_data", MultiJson.dump(json))
        raise ApplicationController::RenderEmpty.new
      end

      format.json { render json: json, status: status_code }
    end
  end

  def second_factor_auth_perform
    nonce = params.require(:nonce)
    challenge = nil
    error_key = nil
    user = nil
    status_code = 200
    begin
      challenge =
        SecondFactor::AuthManager.find_second_factor_challenge(
          nonce: nonce,
          secure_session: secure_session,
          target_user: current_user,
        )
      user = User.find(challenge[:target_user_id])
    rescue SecondFactor::BadChallenge => exception
      error_key = exception.error_translation_key
      status_code = exception.status_code
    end

    if error_key
      json =
        failed_json.merge(
          ok: false,
          error: I18n.t(error_key),
          reason: "challenge_not_found_or_expired",
        )
      render json: failed_json.merge(json), status: status_code
      return
    end

    # no proper error messages for these cases because the only way they can
    # happen is if someone is messing with us.
    # the first one can only happen if someone disables a 2FA method after
    # they're redirected to the 2fa page and then uses the same method they've
    # disabled.
    second_factor_method = params[:second_factor_method].to_i
    if !user.valid_second_factor_method_for_user?(second_factor_method)
      raise Discourse::InvalidAccess.new
    end
    # and this happens if someone tries to use a 2FA method that's not accepted
    # for the action they're trying to perform. e.g. using backup codes to
    # grant someone admin status.
    if !challenge[:allowed_methods].include?(second_factor_method)
      raise Discourse::InvalidAccess.new
    end

    if !challenge[:successful]
      rate_limit_second_factor!(user)
      second_factor_auth_result = user.authenticate_second_factor(params, secure_session)
      if second_factor_auth_result.ok
        challenge[:successful] = true
        challenge[:generated_at] += 1.minute.to_i
        secure_session["current_second_factor_auth_challenge"] = challenge.to_json
      else
        error_json =
          second_factor_auth_result
            .to_h
            .deep_symbolize_keys
            .slice(:ok, :error, :reason)
            .merge(failed_json)
        render json: error_json, status: 400
        return
      end
    end
    render json: {
             ok: true,
             callback_method: challenge[:callback_method],
             callback_path: challenge[:callback_path],
             redirect_url: challenge[:redirect_url],
           },
           status: 200
  end

  def forgot_password
    params.require(:login)

    if ScreenedIpAddress.should_block?(request.remote_ip)
      return render_json_error(I18n.t("login.reset_not_allowed_from_ip_address"))
    end

    RateLimiter.new(nil, "forgot-password-hr-#{request.remote_ip}", 6, 1.hour).performed!
    RateLimiter.new(nil, "forgot-password-min-#{request.remote_ip}", 3, 1.minute).performed!

    user =
      if SiteSetting.hide_email_address_taken && !current_user&.staff?
        if !EmailAddressValidator.valid_value?(normalized_login_param)
          raise Discourse::InvalidParameters.new(:login)
        end
        User.real.where(staged: false).find_by_email(Email.downcase(normalized_login_param))
      else
        User.real.where(staged: false).find_by_username_or_email(normalized_login_param)
      end

    if user
      raise Discourse::ReadOnly if staff_writes_only_mode? && !user.staff?
      enqueue_password_reset_for_user(user)
    else
      RateLimiter.new(
        nil,
        "forgot-password-login-hour-#{normalized_login_param}",
        5,
        1.hour,
      ).performed!
    end

    json = success_json
    json[:user_found] = user.present? if !SiteSetting.hide_email_address_taken
    render json: json
  rescue RateLimiter::LimitExceeded
    render_json_error(I18n.t("rate_limiter.slow_down"))
  end

  def current
    if current_user.present?
      render_serialized(current_user, CurrentUserSerializer, { login_method: login_method })
    else
      render body: nil, status: 404
    end
  end

  def destroy
    redirect_url = params[:return_url].presence || SiteSetting.logout_redirect.presence

    sso = SiteSetting.enable_discourse_connect
    only_one_authenticator =
      !SiteSetting.enable_local_logins && Discourse.enabled_authenticators.length == 1
    if SiteSetting.login_required && (sso || only_one_authenticator)
      # In this situation visiting most URLs will start the auth process again
      # Go to the `/login` page to avoid an immediate redirect
      redirect_url ||= path("/login")
    end

    redirect_url ||= path("/")

    event_data = {
      redirect_url: redirect_url,
      user: current_user,
      client_ip: request&.ip,
      user_agent: request&.user_agent,
    }
    DiscourseEvent.trigger(:before_session_destroy, event_data, **Discourse::Utils::EMPTY_KEYWORDS)
    redirect_url = event_data[:redirect_url]

    reset_session
    log_off_user
    if request.xhr?
      render json: { redirect_url: redirect_url }
    else
      redirect_to redirect_url, allow_other_host: true
    end
  end

  def get_honeypot_value
    secure_session.set(HONEYPOT_KEY, honeypot_value, expires: 1.hour)
    secure_session.set(CHALLENGE_KEY, challenge_value, expires: 1.hour)

    render json: {
             value: honeypot_value,
             challenge: challenge_value,
             expires_in: SecureSession.expiry,
           }
  end

  def scopes
    if is_api?
      key = request.env[Auth::DefaultCurrentUserProvider::HEADER_API_KEY]
      api_key = ApiKey.active.with_key(key).first
      render_serialized(api_key.api_key_scopes, ApiKeyScopeSerializer, root: "scopes")
    else
      render body: nil, status: 404
    end
  end

  protected

  def normalized_login_param
    login = params[:login].to_s
    if login.present?
      login = login[1..-1] if login[0] == "@"
      User.normalize_username(login.strip)[0..100]
    else
      nil
    end
  end

  def check_local_login_allowed(user: nil, check_login_via_email: false)
    # admin-login can get around enabled SSO/disabled local logins
    return if user&.admin?

    if (check_login_via_email && !SiteSetting.enable_local_logins_via_email) ||
         SiteSetting.enable_discourse_connect || !SiteSetting.enable_local_logins
      raise Discourse::InvalidAccess, "SSO takes over local login or the local login is disallowed."
    end
  end

  private

  def connect_verbose_warn(&blk)
    Rails.logger.warn(blk.call) if SiteSetting.verbose_discourse_connect_logging
  end

  def authenticate_second_factor(user)
    second_factor_authentication_result = user.authenticate_second_factor(params, secure_session)
    if !second_factor_authentication_result.ok
      failure_payload = second_factor_authentication_result.to_h
      if user.security_keys_enabled?
        DiscourseWebauthn.stage_challenge(user, secure_session)
        failure_payload.merge!(DiscourseWebauthn.allowed_credentials(user, secure_session))
      end
      @second_factor_failure_payload = failed_json.merge(failure_payload)
      return second_factor_authentication_result
    end

    second_factor_authentication_result
  end

  def login_error_check(user)
    return failed_to_login(user) if user.suspended?

    return not_allowed_from_ip_address(user) if ScreenedIpAddress.should_block?(request.remote_ip)

    if ScreenedIpAddress.block_admin_login?(user, request.remote_ip)
      admin_not_allowed_from_ip_address(user)
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
             reason: "not_activated",
             sent_to_email: user.find_email || user.email,
             current_email: user.email,
           }
  end

  def not_allowed_from_ip_address(user)
    { error: I18n.t("login.not_allowed_from_ip_address", username: user.username) }
  end

  def admin_not_allowed_from_ip_address(user)
    { error: I18n.t("login.admin_not_allowed_from_ip_address", username: user.username) }
  end

  def failed_to_login(user)
    { error: user.suspended_message, reason: "suspended" }
  end

  def login(user, passkey_login: false, second_factor_auth_result: nil)
    session.delete(ACTIVATE_USER_KEY)
    user.update_timezone_if_missing(params[:timezone])
    log_on_user(user)

    if payload = cookies.delete(:sso_payload)
      confirmed_2fa_during_login =
        passkey_login ||
          (
            second_factor_auth_result&.ok && second_factor_auth_result.used_2fa_method.present? &&
              second_factor_auth_result.used_2fa_method != UserSecondFactor.methods[:backup_codes]
          )
      sso_provider(payload, confirmed_2fa_during_login)
    else
      render_serialized(user, UserSerializer)
    end
  end

  def rate_limit_login
    RateLimiter.new(
      nil,
      "login-hr-#{request.remote_ip}",
      SiteSetting.max_logins_per_ip_per_hour,
      1.hour,
    ).performed!

    RateLimiter.new(
      nil,
      "login-min-#{request.remote_ip}",
      SiteSetting.max_logins_per_ip_per_minute,
      1.minute,
    ).performed!
  end

  def render_sso_error(status:, text:)
    @sso_error = text
    render status: status, layout: "no_ember"
  end

  # extension to allow plugins to customize the SSO URL
  def sso_url(sso)
    sso.to_url
  end

  # the invite_key will be present if set in InvitesController
  # when the user visits an /invites/xxxx link; however we do
  # not want to complete the SSO process of creating a user
  # and redeeming the invite if the invite is not redeemable or
  # for the wrong user
  def validate_invitiation!(sso)
    invite_key = secure_session["invite-key"]
    return if invite_key.blank?

    invite = Invite.find_by(invite_key: invite_key)

    if invite.blank?
      raise Invite::ValidationFailed.new(I18n.t("invite.not_found", base_url: Discourse.base_url))
    end

    if invite.redeemable?
      if invite.is_email_invite? && sso.email != invite.email
        raise Invite::ValidationFailed.new(I18n.t("invite.not_matching_email"))
      end
    elsif invite.expired?
      raise Invite::ValidationFailed.new(I18n.t("invite.expired", base_url: Discourse.base_url))
    elsif invite.redeemed?
      raise Invite::ValidationFailed.new(
              I18n.t(
                "invite.not_found_template",
                site_name: SiteSetting.title,
                base_url: Discourse.base_url,
              ),
            )
    end

    invite
  end

  def redeem_invitation(invite, sso, redeeming_user)
    InviteRedeemer.new(
      invite: invite,
      username: sso.username,
      name: sso.name,
      ip_address: request.remote_ip,
      session: session,
      email: sso.email,
      redeeming_user: redeeming_user,
    ).redeem
    secure_session["invite-key"] = nil

    # note - more specific errors are handled in the sso_login method
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
    Rails.logger.warn("SSO invite redemption failed: #{e}")
    raise Invite::RedemptionFailed
  end

  def domain_redirect_allowed?(hostname)
    allowed_domains = SiteSetting.discourse_connect_allowed_redirect_domains
    return false if allowed_domains.blank?
    return true if allowed_domains.split("|").include?("*")

    allowed_domains.split("|").include?(hostname)
  end

  def enqueue_password_reset_for_user(user)
    RateLimiter.new(
      nil,
      "forgot-password-login-day-#{user.username}",
      FORGOT_PASSWORD_EMAIL_LIMIT_PER_DAY,
      1.day,
    ).performed!

    email_token =
      user.email_tokens.create!(email: user.email, scope: EmailToken.scopes[:password_reset])

    Jobs.enqueue(
      :critical_user_email,
      type: "forgot_password",
      user_id: user.id,
      email_token: email_token.token,
    )
  end
end
