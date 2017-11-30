class OfflineController < ApplicationController
  layout false
  skip_before_action :preload_json, :check_xhr, :redirect_to_login_if_required

  def index
    render :offline, content_type: 'text/html'
  end
end
