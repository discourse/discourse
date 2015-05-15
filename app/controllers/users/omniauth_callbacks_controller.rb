# -*- encoding : utf-8 -*-
require_dependency 'email'
require_dependency 'enum'
require_dependency 'user_name_suggester'

class Users::OmniauthCallbacksController < ApplicationController

  BUILTIN_AUTH = [
    Auth::FacebookAuthenticator.new,
    Auth::OpenIdAuthenticator.new("google", "https://www.google.com/accounts/o8/id", trusted: true),
    Auth::GoogleOAuth2Authenticator.new,
    Auth::OpenIdAuthenticator.new("yahoo", "https://me.yahoo.com", trusted: true),
    Auth::GithubAuthenticator.new,
    Auth::TwitterAuthenticator.new
  ]

  skip_before_filter :redirect_to_login_if_required

  layout false

  def self.types
    @types ||= Enum.new(:facebook, :twitter, :google, :yahoo, :github, :persona, :cas)
  end

  # need to be able to call this
  skip_before_filter :check_xhr

  # this is the only spot where we allow CSRF, our openid / oauth redirect
  # will not have a CSRF token, however the payload is all validated so its safe
  skip_before_filter :verify_authenticity_token, only: :complete

  def complete
    auth = request.env["omniauth.auth"]
    auth[:session] = session

    authenticator = self.class.find_authenticator(params[:provider])

    @data = authenticator.after_authenticate(auth)
    @data.authenticator_name = authenticator.name

    complete_response_data

    respond_to do |format|
      format.html
      format.json { render json: @data.to_client_hash }
    end
  end

  def failure
    flash[:error] = I18n.t("login.omniauth_error")
    render layout: 'no_ember'
  end


  def self.find_authenticator(name)
    BUILTIN_AUTH.each do |authenticator|
      if authenticator.name == name
        raise Discourse::InvalidAccess.new("provider is not enabled") unless SiteSetting.send("enable_#{name}_logins?")
        return authenticator
      end
    end

    Discourse.auth_providers.each do |provider|
      return provider.authenticator if provider.name == name
    end

    raise Discourse::InvalidAccess.new("provider is not found")
  end

  protected

  def complete_response_data
    if @data.user
      user_found(@data.user)
    elsif SiteSetting.invite_only?
      @data.requires_invite = true
    else
      session[:authentication] = @data.session_data
    end
  end

  def user_found(user)
    # automatically activate any account if a provider marked the email valid
    if !user.active && @data.email_valid
      user.toggle(:active).save
    end

    if ScreenedIpAddress.should_block?(request.remote_ip)
      @data.not_allowed_from_ip_address = true
    elsif ScreenedIpAddress.block_admin_login?(user, request.remote_ip)
      @data.admin_not_allowed_from_ip_address = true
    elsif Guardian.new(user).can_access_forum? && user.active # log on any account that is active with forum access
      log_on_user(user)
      Invite.invalidate_for_email(user.email) # invite link can't be used to log in anymore
      session[:authentication] = nil # don't carry around old auth info, perhaps move elsewhere
      @data.authenticated = true
    else
      if SiteSetting.must_approve_users? && !user.approved?
        @data.awaiting_approval = true
      else
        @data.awaiting_activation = true
      end
    end
  end

end
