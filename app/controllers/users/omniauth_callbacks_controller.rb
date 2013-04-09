# -*- encoding : utf-8 -*-
require_dependency 'email'
require_dependency 'enum'

class Users::OmniauthCallbacksController < ApplicationController

  layout false

  def self.types
    @types ||= Enum.new(:facebook, :twitter, :google, :yahoo, :github, :persona)
  end

  # need to be able to call this
  skip_before_filter :check_xhr

  # must be done, cause we may trigger a POST
  skip_before_filter :verify_authenticity_token, only: :complete

  def complete
    # Make sure we support that provider
    provider = params[:provider]
    raise Discourse::InvalidAccess.new unless self.class.types.keys.map(&:to_s).include?(provider)

    # Check if the provider is enabled
    raise Discourse::InvalidAccess.new("provider is not enabled") unless SiteSetting.send("enable_#{provider}_logins?")

    # Call the appropriate logic
    send("create_or_sign_on_user_using_#{provider}", request.env["omniauth.auth"])

    respond_to do |format|
      format.html
      format.json { render json: @data }
    end
  end

  def failure
    flash[:error] = I18n.t("login.omniauth_error", strategy: params[:strategy].titleize)
    render layout: 'no_js'
  end

  def create_or_sign_on_user_using_twitter(auth_token)

    data = auth_token[:info]
    screen_name = data["nickname"]
    twitter_user_id = auth_token["uid"]

    session[:authentication] = {
      twitter_user_id: twitter_user_id,
      twitter_screen_name: screen_name
    }

    user_info = TwitterUserInfo.where(twitter_user_id: twitter_user_id).first

    @data = {
      username: screen_name,
      auth_provider: "Twitter"
    }

    if user_info
      if user_info.user.active
        if Guardian.new(user_info.user).can_access_forum?
          log_on_user(user_info.user)
          @data[:authenticated] = true
        else
          @data[:awaiting_approval] = true
        end
      else
        @data[:awaiting_activation] = true
        # send another email ?
      end
    else
      @data[:name] = screen_name
    end

  end

  def create_or_sign_on_user_using_facebook(auth_token)

    data = auth_token[:info]
    raw_info = auth_token["extra"]["raw_info"]

    email = data[:email]
    name = data["name"]
    fb_uid = auth_token["uid"]


    username = User.suggest_username(name)

    session[:authentication] = {
      facebook: {
        facebook_user_id: fb_uid ,
        link: raw_info["link"],
        username: raw_info["username"],
        first_name: raw_info["first_name"],
        last_name: raw_info["last_name"],
        email: raw_info["email"],
        gender: raw_info["gender"],
        name: raw_info["name"]
      },
      email: email,
      email_valid: true
    }

    user_info = FacebookUserInfo.where(facebook_user_id: fb_uid).first

    @data = {
      username: username,
      name: name,
      email: email,
      auth_provider: "Facebook",
      email_valid: true
    }

    if user_info
      user = user_info.user
      if user
        unless user.active
          user.active = true
          user.save
        end

        # If we have to approve users
        if Guardian.new(user).can_access_forum?
          log_on_user(user)
          @data[:authenticated] = true
        else
          @data[:awaiting_approval] = true
        end
      end
    else
      user = User.where(email: email).first
      if user
        FacebookUserInfo.create!(session[:authentication][:facebook].merge(user_id: user.id))
        unless user.active
          user.active = true
          user.save
        end
        log_on_user(user)
        @data[:authenticated] = true
      end
    end

  end

  def create_or_sign_on_user_using_openid(auth_token)

    data = auth_token[:info]
    identity_url = auth_token[:extra][:identity_url]

    email = data[:email]

    # If the auth supplies a name / username, use those. Otherwise start with email.
    name = data[:name] || data[:email]
    username = data[:nickname] || data[:email]

    user_open_id = UserOpenId.find_by_url(identity_url)

    if user_open_id.blank? && user = User.find_by_email(email)
      # we trust so do an email lookup
      user_open_id = UserOpenId.create(url: identity_url , user_id: user.id, email: email, active: true)
    end

    authenticated = user_open_id # if authed before

    if authenticated
      user = user_open_id.user

      # If we have to approve users
      if Guardian.new(user).can_access_forum?
        log_on_user(user)
        @data = {authenticated: true}
      else
        @data = {awaiting_approval: true}
      end

    else
      @data = {
        email: email,
        name: User.suggest_name(name),
        username: User.suggest_username(username),
        email_valid: true ,
        auth_provider: data[:provider] || params[:provider].try(:capitalize)
      }
      session[:authentication] = {
        email: @data[:email],
        email_valid: @data[:email_valid],
        openid_url: identity_url
      }
    end

  end

  alias_method :create_or_sign_on_user_using_yahoo, :create_or_sign_on_user_using_openid
  alias_method :create_or_sign_on_user_using_google, :create_or_sign_on_user_using_openid

  def create_or_sign_on_user_using_github(auth_token)

    data = auth_token[:info]
    screen_name = data["nickname"]
    github_user_id = auth_token["uid"]

    session[:authentication] = {
      github_user_id: github_user_id,
      github_screen_name: screen_name
    }

    user_info = GithubUserInfo.where(github_user_id: github_user_id).first

    @data = {
      username: screen_name,
      auth_provider: "Github"
    }

    if user_info
      if user_info.user.active

        if Guardian.new(user_info.user).can_access_forum?
          log_on_user(user_info.user)
          @data[:authenticated] = true
        else
          @data[:awaiting_approval] = true
        end

      else
        @data[:awaiting_activation] = true
        # send another email ?
      end
    else
      @data[:name] = screen_name
    end

  end

  def create_or_sign_on_user_using_persona(auth_token)

    email = auth_token[:info][:email]

    user = User.find_by_email(email)

    if user

      if Guardian.new(user).can_access_forum?
        log_on_user(user)
        @data = {authenticated: true}
      else
        @data = {awaiting_approval: true}
      end

    else
      @data = {
        email: email,
        email_valid: true,
        name: User.suggest_name(email),
        username: User.suggest_username(email),
        auth_provider: params[:provider].try(:capitalize)
      }

      session[:authentication] = {
        email: email,
        email_valid: true,
      }
    end

  end

end
