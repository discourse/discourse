# -*- encoding : utf-8 -*-
require_dependency 'email'
require_dependency 'enum'
require_dependency 'user_name_suggester'

class Users::OmniauthCallbacksController < ApplicationController

  BUILTIN_AUTH = [
    Auth::FacebookAuthenticator.new,
    Auth::GoogleOAuth2Authenticator.new,
    Auth::OpenIdAuthenticator.new("yahoo", "https://me.yahoo.com", trusted: true),
    Auth::GithubAuthenticator.new,
    Auth::TwitterAuthenticator.new,
    Auth::InstagramAuthenticator.new
  ]

  skip_before_action :redirect_to_login_if_required

  layout 'no_ember'

  def self.types
    @types ||= Enum.new(:facebook, :instagram, :twitter, :google, :yahoo, :github, :persona, :cas)
  end

  # need to be able to call this
  skip_before_action :check_xhr

  # this is the only spot where we allow CSRF, our openid / oauth redirect
  # will not have a CSRF token, however the payload is all validated so its safe
  skip_before_action :verify_authenticity_token, only: :complete

  def complete
    auth = request.env["omniauth.auth"]
    raise Discourse::NotFound unless request.env["omniauth.auth"]

    auth[:session] = session

    authenticator = self.class.find_authenticator(params[:provider])
    provider = Discourse.auth_providers && Discourse.auth_providers.find { |p| p.name == params[:provider] }

    @auth_result = authenticator.after_authenticate(auth)

    origin = request.env['omniauth.origin']

    if cookies[:destination_url].present?
      origin = cookies[:destination_url]
      cookies.delete(:destination_url)
    end

    if origin.present?
      parsed = begin
        URI.parse(origin)
      rescue URI::InvalidURIError
      end

      if parsed
        @origin = "#{parsed.path}?#{parsed.query}"
      end
    end

    if @origin.blank?
      @origin = Discourse.base_uri("/")
    else
      @auth_result.destination_url = origin
    end

    if @auth_result.failed?
      flash[:error] = @auth_result.failed_reason.html_safe
      return render('failure')
    else
      @auth_result.authenticator_name = authenticator.name
      complete_response_data

      if (provider && provider.full_screen_login) || cookies['fsl']
        cookies.delete('fsl')
        cookies['_bypass_cache'] = true
        flash[:authentication_data] = @auth_result.to_client_hash.to_json
        redirect_to @origin
      else
        respond_to do |format|
          format.html
          format.json { render json: @auth_result.to_client_hash }
        end
      end
    end
  end

  def failure
    flash[:error] = I18n.t("login.omniauth_error")
    render 'failure'
  end

  def self.find_authenticator(name)
    BUILTIN_AUTH.each do |authenticator|
      if authenticator.name == name
        raise Discourse::InvalidAccess.new(I18n.t("provider_not_enabled")) unless SiteSetting.send("enable_#{name}_logins?")
        return authenticator
      end
    end

    Discourse.auth_providers.each do |provider|
      unless provider.enabled_setting.nil? || SiteSetting.send(provider.enabled_setting)
        raise Discourse::InvalidAccess.new(I18n.t("provider_not_enabled"))
      end
      return provider.authenticator if provider.name == name
    end

    raise Discourse::InvalidAccess.new(I18n.t("provider_not_found"))
  end

  protected

  def complete_response_data
    if @auth_result.user
      user_found(@auth_result.user)
    elsif SiteSetting.invite_only?
      @auth_result.requires_invite = true
    else
      session[:authentication] = @auth_result.session_data
    end
  end

  def user_found(user)
    if user.totp_enabled?
      @auth_result.omniauth_disallow_totp = true
      @auth_result.email = user.email
      return
    end

    # automatically activate/unstage any account if a provider marked the email valid
    if @auth_result.email_valid && @auth_result.email == user.email
      user.unstage
      user.save

      # ensure there is an active email token
      unless EmailToken.where(email: user.email, confirmed: true).exists? ||
        user.email_tokens.active.where(email: user.email).exists?

        user.email_tokens.create!(email: user.email)
      end

      user.activate
      user.update!(registration_ip_address: request.remote_ip) if user.registration_ip_address.blank?
    end

    if ScreenedIpAddress.should_block?(request.remote_ip)
      @auth_result.not_allowed_from_ip_address = true
    elsif ScreenedIpAddress.block_admin_login?(user, request.remote_ip)
      @auth_result.admin_not_allowed_from_ip_address = true
    elsif Guardian.new(user).can_access_forum? && user.active # log on any account that is active with forum access
      log_on_user(user)
      Invite.invalidate_for_email(user.email) # invite link can't be used to log in anymore
      session[:authentication] = nil # don't carry around old auth info, perhaps move elsewhere
      @auth_result.authenticated = true
    else
      if SiteSetting.must_approve_users? && !user.approved?
        @auth_result.awaiting_approval = true
      else
        @auth_result.awaiting_activation = true
      end
    end
  end

end
