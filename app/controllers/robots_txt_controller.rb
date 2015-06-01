class RobotsTxtController < ApplicationController
  layout false
  skip_before_filter :preload_json, :check_xhr

  def index
    path = if SiteSetting.allow_index_in_robots_txt
      :index
    else
      :no_index
    end

    render path, content_type: 'text/plain'
  end
end
