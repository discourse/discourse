class UploadsController < ApplicationController
  before_filter :ensure_logged_in

  def create
    requires_parameter(:topic_id)
    file = params[:file] || params[:files].first
    # only supports images for now
    return render status: 415, json: failed_json unless file.content_type =~ /^image\/.+/
    upload = Upload.create_for(current_user.id, file, params[:topic_id])
    render_serialized(upload, UploadSerializer, root: false)
  end
end
