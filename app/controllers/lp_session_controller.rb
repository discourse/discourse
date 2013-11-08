class LpSessionController < ApplicationController

  skip_before_filter :verify_authenticity_token
  skip_before_filter :sync_main_app_session
  skip_before_filter :check_xhr

  def new
    session[:back_to] = params[:back_to] || request.referrer
    redirect_to '/auth/lessonplanet'
  end

  def create
    oauth_token = request.env["omniauth.auth"]['credentials']['token']
    main_app_session.create(oauth_token)
    next_url = session.delete(:back_to) || '/'
    redirect_to "#{next_url}?#{Time.now.to_i}" # Force reload
  end

  def destroy
    main_app_session.destroy
    next_url = request.referrer || root_url
    redirect_to "#{ENV['LESSON_PLANET_AUTH_URL']}/logout?url=#{next_url}"
  end

end
