class RobotsTxtController < ApplicationController
  layout false
  skip_before_filter :preload_json, :check_xhr, :redirect_to_login_if_required

  def index
    path = SiteSetting.allow_index_in_robots_txt ? :index : :no_index
    render path, content_type: 'text/plain'
  end
end
