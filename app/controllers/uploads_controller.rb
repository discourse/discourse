class UploadsController < ApplicationController
  def create
    file = params[:file] || params[:files].first
    upload = Upload.create_for(current_user, file, params[:topic_id])
    render_serialized(upload, UploadSerializer, root: false)
  end
end
