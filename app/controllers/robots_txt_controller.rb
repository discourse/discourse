class RobotsTxtController < ApplicationController
  layout false
  skip_before_filter :check_xhr
  skip_before_filter :check_restricted_access

  def index
    path = if SiteSetting.allow_index_in_robots_txt && SiteSetting.access_password.blank?
      :index
    else
      :no_index
    end

    render path, content_type: 'text/plain'
  end
end
