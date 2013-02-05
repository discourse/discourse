class TwitterController < ApplicationController
  skip_before_filter :check_xhr, only: [:frame, :complete]
  layout false

  def frame 

    # defer the require as late as possible
    require 'oauth'

    consumer = oauth_consumer
    host = request.host 
    host = "#{host}:#{request.port}" if request.port != 80
    request_token = consumer.get_request_token(:oauth_callback => "http://#{host}/twitter/complete")

    session[:request_token] = request_token.token
    session[:request_token_secret] = request_token.secret

    redirect_to request_token.authorize_url
  end

  def complete

    require 'oauth'
    
    consumer = oauth_consumer
    
    unless session[:request_token] && session[:request_token_secret] 
      render :text => ('No authentication information was found in the session. Please try again.') and return
    end

    unless params[:oauth_token].blank? || session[:request_token] ==  params[:oauth_token]
      render :text => ('Authentication information does not match session information. Please try again.') and return
    end

    request_token = OAuth::RequestToken.new(consumer, session[:request_token], session[:request_token_secret])
    access_token = request_token.get_access_token(:oauth_verifier => params[:oauth_verifier])

    session[:request_token] = request_token.token
    session[:request_token_secret] = request_token.secret

    screen_name = access_token.params["screen_name"]
    twitter_user_id = access_token.params["user_id"]
    
    session[:authentication] = {
      twitter_user_id: twitter_user_id,
      twitter_screen_name: screen_name
    }
  
    user_info = TwitterUserInfo.where(:twitter_user_id => twitter_user_id).first

    @data = {
      username: screen_name,
      auth_provider: "Twitter"
    }
    
    if user_info
      if user_info.user.active
        log_on_user(user_info.user)
        @data[:authenticated] = true
      else
        @data[:awaiting_activation] = true
        # send another email ? 
      end
    else
      #TODO typheous or some other webscale http request lib that does not block thins
      require 'open-uri'
      parsed = ::JSON.parse(open("http://api.twitter.com/1/users/show.json?screen_name=#{screen_name}").read)
      @data[:name] = parsed["name"]
    end

  end


  protected 

  def oauth_consumer
    OAuth::Consumer.new(
      SiteSetting.twitter_consumer_key, 
      SiteSetting.twitter_consumer_secret,
      :site => "https://api.twitter.com",
      :authorize_path => '/oauth/authenticate'
    )
  end

end
