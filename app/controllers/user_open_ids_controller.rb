require_dependency 'email'

class UserOpenIdsController < ApplicationController
  layout false

  # need to be able to call this
  skip_before_filter :check_xhr

  # must be done, cause we may trigger a POST
  skip_before_filter :verify_authenticity_token, :only => :complete

  def destroy
    @open_id = UserOpenId.find(params[:id])
    if @open_id.user.id == current_user.id
      @open_id.destroy
    end
    redirect_to current_user
  end

  def new
    @open_id = UserOpenId.new
  end

  def complete
    auth_token = env["omniauth.auth"]
    create_or_sign_on_user(auth_token)
  end

  def create_or_sign_on_user(auth_token)

    data = auth_token[:info]
    identity_url = auth_token[:extra][:identity_url]

    email = data[:email]

    user_open_id = UserOpenId.find_by_url(identity_url)

    if user_open_id.blank? && user = User.find_by_email(email)
      # we trust so do an email lookup
      user_open_id = UserOpenId.create(url: identity_url , user_id: user.id, email: email, active: true)
    end

    authenticated = user_open_id # if authed before

    if authenticated
      user = user_open_id.user

      # If we have to approve users
      if SiteSetting.must_approve_users? and !user.approved?
        @data = {awaiting_approval: true}
      else
        log_on_user(user)
        @data = {authenticated: true}
      end

    else
      @data = {
        email: email,
        name: User.suggest_name(email),
        username: User.suggest_username(email),
        email_valid: true ,
        auth_provider: data[:provider]
      }
      session[:authentication] = {
        email: @data[:email],
        email_valid: @data[:email_valid],
        openid_url: identity_url
      }
    end
  end

end
