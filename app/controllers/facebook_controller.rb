class FacebookController < ApplicationController
  skip_before_filter :check_xhr, only: [:frame, :complete]
  layout false

  def frame 
    redirect_to oauth_consumer.url_for_oauth_code(:permissions => "email")
  end

  def complete
    consumer = oauth_consumer
    token = consumer.get_access_token(params[:code])

    graph = Koala::Facebook::API.new(token)
    me = graph.get_object("me")

    email = me["email"]
    verified = me["verified"]

    name = me["name"]
    username = User.suggest_username(me["username"])

    verified = me["verified"]

    # non verified accounts are just trouble
    unless verified
      render text: "Your account must be verified with facebook, before authenticating with facebook"  
      return
    end

    session[:authentication] = {
      facebook: {
        facebook_user_id: me["id"],
        link: me["link"],
        username: me["username"],
        first_name: me["first_name"],
        last_name: me["last_name"],
        email: me["email"],
        gender: me["gender"],
        name: me["name"]
      },
      email: me["email"],
      email_valid: true
    }
  
    user_info = FacebookUserInfo.where(:facebook_user_id => me["id"]).first

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
        log_on_user(user)
        @data[:authenticated] = true
      end
    else 
      user = User.where(email: me["email"]).first
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


  protected 

  def oauth_consumer
    require 'koala'

    host = request.host 
    host = "#{host}:#{request.port}" if request.port != 80
    callback_url = "http://#{host}/facebook/complete"
    
    oauth = Koala::Facebook::OAuth.new(SiteSetting.facebook_app_id, SiteSetting.facebook_app_secret, callback_url)
  end

end
