class UploadsController < ApplicationController
  before_filter :ensure_logged_in

  def create
    requires_parameter(:topic_id)
    file = params[:file] || params[:files].first
    upload = Upload.create_for(current_user, file, params[:topic_id])
    render_serialized(upload, UploadSerializer, root: false)
  end
end
