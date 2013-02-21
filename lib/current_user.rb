module CurrentUser

  def self.lookup_from_env(env)
    request = Rack::Request.new(env)
    auth_token = request.cookies[:_t]
    user = nil
    if auth_token && auth_token.length == 32
      user = User.where(auth_token: auth_token).first 
    end
    
    return user
  end

  def current_user
    return @current_user if @current_user || @not_logged_in

    if session[:current_user_id].blank?
      # maybe we have a cookie? 
      auth_token = cookies.signed[:_t]
      if auth_token && auth_token.length == 32
        @current_user = User.where(auth_token: auth_token).first
        session[:current_user_id] = @current_user.id if @current_user
      end
    else
      @current_user ||= User.where(id: session[:current_user_id]).first
    end

    if @current_user && @current_user.is_banned? 
      @current_user = nil
    end

    @not_logged_in = session[:current_user_id].blank?
    if @current_user
      @current_user.update_last_seen! 
      if (@current_user.ip_address != request.remote_ip) and request.remote_ip.present?
        @current_user.ip_address = request.remote_ip
        @current_user.update_column(:ip_address, request.remote_ip)
      end
    end
    @current_user
  end

end
