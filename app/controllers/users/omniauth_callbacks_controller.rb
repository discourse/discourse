# -*- encoding : utf-8 -*-
require_dependency 'email'
require_dependency 'enum'
require_dependency 'user_name_suggester'

class Users::OmniauthCallbacksController < ApplicationController
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
    provider = params[:provider]

    # If we are a plugin, then try to login with it
    found = false
    Discourse.auth_providers.each do |p|
      if p.name == provider && p.type == :open_id
        create_or_sign_on_user_using_openid request.env["omniauth.auth"]
        found = true
        break
      elsif p.name == provider && p.type == :oauth2
        create_or_sign_on_user_using_oauth2 request.env["omniauth.auth"]
        found = true
        break
      end
    end

    unless found
      # Make sure we support that provider
      raise Discourse::InvalidAccess.new unless self.class.types.keys.map(&:to_s).include?(provider)

      # Check if the provider is enabled
      raise Discourse::InvalidAccess.new("provider is not enabled") unless SiteSetting.send("enable_#{provider}_logins?")

      # Call the appropriate logic
      send("create_or_sign_on_user_using_#{provider}", request.env["omniauth.auth"])
    end

    @data[:awaiting_approval] = true if invite_only?

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

    process_user_info(user_info, screen_name)
  end

  def create_or_sign_on_user_using_facebook(auth_token)

    data = auth_token[:info]
    raw_info = auth_token["extra"]["raw_info"]

    email = data[:email]
    name = data["name"]
    fb_uid = auth_token["uid"]


    username = UserNameSuggester.suggest(name)

    session[:authentication] = {
      facebook: {
        facebook_user_id: fb_uid,
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
      if user = user_info.user
        user.toggle(:active).save unless user.active?

        # If we have to approve users
        if Guardian.new(user).can_access_forum?
          log_on_user(user)
          @data[:authenticated] = true
        else
          @data[:awaiting_approval] = true
        end
      end
    else
      if user = User.where(email: email).first
        user.create_facebook_user_info! session[:authentication][:facebook]
        user.toggle(:active).save unless user.active?
        log_on_user(user)
        @data[:authenticated] = true
      end
    end

  end

  def create_or_sign_on_user_using_cas(auth_token)
    logger.error "authtoken #{auth_token}"

    email = auth_token[:info][:email] if auth_token[:info]
    email ||= if SiteSetting.cas_domainname.present?
      "#{auth_token[:extra][:user]}@#{SiteSetting.cas_domainname}"
    else
      auth_token[:extra][:user]
    end

    username = auth_token[:extra][:user]

    name = if auth_token[:info] && auth_token[:info][:name]
      auth_token[:info][:name]
    else
      auth_token["uid"]
    end

    cas_user_id = auth_token["uid"]

    session[:authentication] = {
        cas: {
            cas_user_id: cas_user_id ,
            username: username
        },
        email: email,
        email_valid: true
    }

    user_info = CasUserInfo.where(:cas_user_id => cas_user_id ).first

    @data = {
        username: username,
        name: name,
        email: email,
        auth_provider: "CAS",
        email_valid: true
    }

    if user_info
      if user = user_info.user
        user.toggle(:active).save unless user.active?
        log_on_user(user)
        @data[:authenticated] = true
      end
    else
      user = User.where(email: email).first
      if user
        CasUserInfo.create!(session[:authentication][:cas].merge(user_id: user.id))
        user.toggle(:active).save unless user.active?
        log_on_user(user)
        @data[:authenticated] = true
      end
    end

  end

  def create_or_sign_on_user_using_oauth2(auth_token)
    oauth2_provider = auth_token[:provider]
    oauth2_uid = auth_token[:uid]
    data = auth_token[:info]
    email = data[:email]
    name = data[:name]

    oauth2_user_info = Oauth2UserInfo.where(uid: oauth2_uid, provider: oauth2_provider).first

    if oauth2_user_info.blank? && user = User.find_by_email(email)
      # TODO is only safe if we trust our oauth2 provider to return an email
      # legitimately owned by our user
      oauth2_user_info = Oauth2UserInfo.create(uid: oauth2_uid,
                                               provider: oauth2_provider,
                                               name: name,
                                               email: email,
                                               user: user)
    end

    authenticated = oauth2_user_info.present?

    if authenticated
      user = oauth2_user_info.user

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
        username: UserNameSuggester.suggest(email),
        email_valid: true ,
        auth_provider: oauth2_provider
      }

      session[:authentication] = {
        oauth2: {
          provider: oauth2_provider,
          uid: oauth2_uid,
        },
        name: name,
        email: @data[:email],
        email_valid: @data[:email_valid]
      }
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
      # TODO some openid providers may not be trust worthy, allow for that
      #  for now we are good (google, yahoo are trust worthy)
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
        username: UserNameSuggester.suggest(username),
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
    email = data["email"]
    github_user_id = auth_token["uid"]

    session[:authentication] = {
      github_user_id: github_user_id,
      github_screen_name: screen_name,
      email: email,
      email_valid: true
    }

    user_info = GithubUserInfo.where(github_user_id: github_user_id).first

    if !user_info && user = User.find_by_email(email)
      # we trust so do an email lookup
      user_info = GithubUserInfo.create(
          user_id: user.id,
          screen_name: screen_name,
          github_user_id: github_user_id
      )
    end

    @data = {
      username: screen_name,
      auth_provider: "Github",
      email: email,
      email_valid: true
    }

    process_user_info(user_info, screen_name)
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
        username: UserNameSuggester.suggest(email),
        auth_provider: params[:provider].try(:capitalize)
      }

      session[:authentication] = {
        email: email,
        email_valid: true,
      }
    end

  end

  private

  def process_user_info(user_info, screen_name)
    if user_info
      if user_info.user.active?

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

  def invite_only?
    SiteSetting.invite_only? && !@data[:authenticated]
  end
end
