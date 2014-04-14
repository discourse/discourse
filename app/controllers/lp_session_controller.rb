class LpSessionController < ApplicationController
  skip_before_filter :verify_authenticity_token
  skip_before_filter :sync_main_app_session
  skip_before_filter :check_xhr

  def destroy
    log_off_user
    next_url = request.referrer || root_url
    redirect_to "#{ENV['LESSON_PLANET_ROOT_URL']}/logout?url=#{next_url}"
  end
end
