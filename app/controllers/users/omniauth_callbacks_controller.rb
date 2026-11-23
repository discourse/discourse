# frozen_string_literal: true

class Users::OmniauthCallbacksController < ApplicationController
  include LoginSecondFactor

  skip_before_action :redirect_to_login_if_required, :redirect_to_profile_if_required

  layout "no_ember"

  # need to be able to call this
  skip_before_action :check_xhr, except: :complete_second_factor

  # this is the only spot where we allow CSRF, our openid / oauth redirect
  # will not have a CSRF token, however the payload is all validated so its safe
  skip_before_action :verify_authenticity_token, only: :complete

  # These are usually GET requests but some providers use POST requests
  allow_in_staff_writes_only_mode :complete, :complete_second_factor
  allow_when_archived :complete, :complete_second_factor

  SECOND_FACTOR_FLOW = "omniauth"

  def confirm_request
    self.class.find_authenticator(params[:provider])
    render locals: { hide_auth_buttons: true }
  end

  def complete
    raise Discourse::ReadOnly if @readonly_mode && !@staff_writes_only_mode
    raise Discourse::NotFound unless auth = request.env["omniauth.auth"]

    auth[:session] = session

    authenticator = self.class.find_authenticator(params[:provider])

    if session.delete(:auth_reconnect) && authenticator.can_connect_existing_user? && current_user
      return redirect_to persist_auth_token(auth)
    else
      DiscourseEvent.trigger(:before_auth, authenticator, auth, session, cookies, request)
      @auth_result = authenticator.after_authenticate(auth)
      @auth_result.user = nil if @auth_result&.user&.staged # Treat staged users the same as unregistered users
      DiscourseEvent.trigger(:after_auth, authenticator, @auth_result, session, cookies, request)
    end

    preferred_origin = request.env["omniauth.origin"]

    session.delete(:destination_url) # Clean up old values. TODO: Remove after March 2026
    if server_session[:destination_url].present?
      preferred_origin = server_session[:destination_url]
    elsif SiteSetting.enable_discourse_connect_provider && payload = cookies.delete(:sso_payload)
      preferred_origin = session_sso_provider_url + "?" + payload
    elsif cookies[:destination_url].present?
      preferred_origin = cookies[:destination_url]
    end

    server_session.delete(:destination_url)
    cookies.delete(:destination_url)

    if preferred_origin.present?
      parsed =
        begin
          URI.parse(preferred_origin)
        rescue URI::Error
        end

      if valid_origin?(parsed)
        @origin = +"#{parsed.path}"
        @origin << "?#{parsed.query}" if parsed.query
      end
    end

    @origin = Discourse.base_path("/") if @origin.blank?

    @auth_result.destination_url = @origin
    @auth_result.authenticator_name = authenticator.name

    return render_auth_result_failure if @auth_result.failed?

    raise Discourse::ReadOnly if @staff_writes_only_mode && !@auth_result.user&.staff?

    if user = @auth_result.user
      unless login_blocked_message(user)
        start_login_second_factor!(
          flow: SECOND_FACTOR_FLOW,
          target_user: user,
          callback_path: omniauth_second_factor_path,
        ) do
          {
            auth_result: @auth_result.session_data,
            origin: @origin,
            account_snapshot: login_account_snapshot(user),
            provider_identity: provider_identity(authenticator, auth, user),
          }
        end
        finish_login(user)
      end
    elsif invite_required?
      @auth_result.requires_invite = true
    else
      signup_authentication = @auth_result.session_data
      if @auth_result.email_valid
        expires_at = Auth::SecondFactorEnrollment::PROOF_LIFETIME.from_now.to_i
        signup_authentication[:enrollment_proof_expires_at] = expires_at
      end
      server_session[:authentication] = signup_authentication
    end

    return render_auth_result_failure if @auth_result.failed?

    association_auth = auth.except(:session) if !@auth_result.user &&
      self_managed_association?(authenticator)
    set_authentication_data(association_auth)

    # If the user account doesn't already exist, and this signup is part of a user-api-key request, direct
    # the user to the homepage first so that signup can be completed. They'll be redirected to the user-api-key
    # route once signup is complete. Hopefully, this can be simplified once fullscreen login/signup is everywhere.
    if !current_user && @origin.start_with?("/user-api-key/new")
      redirect_to path("/")
    else
      redirect_to @origin
    end
  end

  def complete_second_factor
    user, payload = complete_login_second_factor!(flow: SECOND_FACTOR_FLOW)
    raise Discourse::NotFound if user.staged?
    raise Discourse::ReadOnly if @staff_writes_only_mode && !user.staff?

    @auth_result = Auth::Result.from_session_data(payload.fetch(:auth_result), user:)
    @origin = @auth_result.destination_url = payload.fetch(:origin)
    # The provider may have been disabled since the first request.
    self.class.find_authenticator(@auth_result.authenticator_name)

    if message = login_blocked_message(user)
      return render_json_error(message, status: :forbidden)
    end

    if login_account_snapshot(user) != payload[:account_snapshot] ||
         !valid_provider_identity?(user, payload[:provider_identity])
      raise Discourse::InvalidAccess
    end

    finish_login(user)
    return render_json_error(@auth_result.failed_reason) if @auth_result.failed?
    raise Discourse::InvalidAccess unless @auth_result.authenticated

    set_authentication_data
    render json: { redirect_url: @origin, reload: true }
  end

  def valid_origin?(uri)
    return false if uri.nil?
    return false if uri.host.present? && uri.host != Discourse.current_hostname
    if !uri.path&.start_with?("/") || uri.path.start_with?("//") || uri.path.include?("\\")
      return false
    end
    return false if uri.path.start_with?("#{Discourse.base_path}/auth/")
    return false if uri.path.start_with?("#{Discourse.base_path}/login")
    true
  end

  ALLOWED_FAILURE_ERRORS = %w[csrf_detected request_error invalid_iat unauthorized].index_by { it }

  def failure
    error_name = params[:message].to_s.gsub(/[^\w-]/, "").presence
    error = ALLOWED_FAILURE_ERRORS.fetch(error_name, "generic")

    if error == "generic"
      provider_name = params[:provider].presence || params[:strategy].presence
      provider = Discourse.enabled_authenticators.find { it.name == provider_name }&.display_name

      if provider.blank? && Discourse.enabled_authenticators.one?
        provider = Discourse.enabled_authenticators[0].display_name
      end

      error = provider.present? ? "generic_with_provider" : "generic_without_provider"
    end

    flash[:error] = I18n.t("login.omniauth_error.#{error}", provider:)

    render "failure"
  end

  def self.find_authenticator(name)
    if SiteSetting.enable_discourse_connect
      raise Discourse::InvalidAccess.new(I18n.t("authenticator_not_found"))
    end
    Discourse.enabled_authenticators.each do |authenticator|
      return authenticator if authenticator.name == name
    end
    raise Discourse::InvalidAccess.new(I18n.t("authenticator_not_found"))
  end

  protected

  def render_auth_result_failure
    flash[:error] = PrettyText.sanitize(@auth_result.failed_reason).html_safe
    render "failure"
  end

  def invite_required?
    if SiteSetting.invite_only?
      path = Discourse.route_for(@origin)
      return true unless path
      return true if path[:controller] != "invites" || path[:action] != "show"
      !Invite.find_by(invite_key: path[:id])&.redeemable?
    end
  end

  # The provider callback uses these flags for the login page; the JSON continuation uses the message.
  def login_blocked_message(user)
    if user.suspended?
      user.suspended_message
    elsif ScreenedIpAddress.should_block?(request.remote_ip)
      @auth_result.not_allowed_from_ip_address = true
      I18n.t("login.not_allowed_from_ip_address", username: user.username)
    elsif ScreenedIpAddress.block_admin_login?(user, request.remote_ip)
      @auth_result.admin_not_allowed_from_ip_address = true
      I18n.t("login.admin_not_allowed_from_ip_address", username: user.username)
    elsif !user.guardian.can_access_forum?
      @auth_result.awaiting_approval = true
      I18n.t("login.not_approved")
    elsif !user.active? && !provider_verified_email?(user)
      @auth_result.awaiting_activation = true
      I18n.t("login.not_activated")
    end
  end

  def login_account_snapshot(user)
    {
      "email" => user.email,
      "active" => user.active?,
      "password_updated_at" => user.user_password&.updated_at&.iso8601(6),
    }
  end

  def provider_identity(authenticator, auth, user)
    return unless authenticator.is_a?(Auth::ManagedAuthenticator)

    association =
      UserAssociatedAccount.find_by!(
        provider_name: auth[:provider],
        provider_uid: auth[:uid],
        user_id: user.id,
      )
    # Reject stale provider claims, including a later login that changed group membership.
    association.slice(:id, :provider_name, :provider_uid).merge(
      updated_at: association.updated_at.iso8601(6),
    )
  end

  def valid_provider_identity?(user, identity)
    !identity || UserAssociatedAccount.exists?(identity.merge(user_id: user.id))
  end

  def provider_verified_email?(user)
    @auth_result.email_valid && @auth_result.email == user.email
  end

  def finish_login(user)
    # automatically activate any account if a provider marked the email valid
    if provider_verified_email?(user)
      if !user.active || !user.email_confirmed?
        user.update!(password: SecureRandom.hex)

        # Ensure there is an active email token
        if !EmailToken.where(email: user.email, confirmed: true).exists? &&
             !user.email_tokens.active.where(email: user.email).exists?
          user.email_tokens.create!(email: user.email, scope: EmailToken.scopes[:signup])
        end

        user.activate
      end
      if user.registration_ip_address.blank?
        user.update!(registration_ip_address: request.remote_ip)
      end
    end

    unless user.active?
      @auth_result.awaiting_activation = true
      return
    end

    begin
      user.save! if @auth_result.apply_user_attributes!
      @auth_result.apply_associated_attributes!
    rescue ActiveRecord::RecordInvalid => e
      @auth_result.failed = true
      @auth_result.failed_reason = e.record.errors.full_messages.join(", ")
      return
    end

    log_on_user(user, { authenticated_with_oauth: true }, replay_anonymous_action: true)
    Auth::SecondFactorEnrollment.mark_external_login!(request, user)
    Invite.invalidate_for_email(user.email)
    server_session.delete(:authentication)
    @auth_result.authenticated = true
  end

  def self_managed_association?(authenticator)
    authenticator.can_connect_existing_user? &&
      (SiteSetting.enable_local_logins || Discourse.enabled_authenticators.count > 1)
  end

  def set_authentication_data(association_auth = nil)
    client_hash = @auth_result.to_client_hash
    client_hash[:associate_url] = persist_auth_token(association_auth) if association_auth

    cookies["_bypass_cache"] = true
    cookies[:authentication_data] = { value: client_hash.to_json, path: Discourse.base_path("/") }
  end

  def persist_auth_token(auth)
    secret = SecureRandom.hex
    key = Users::AssociateAccountsController.key(secret)
    server_session.set(key, auth.to_json, expires: 10.minutes)
    "#{Discourse.base_path}/associate/#{secret}"
  end
end
