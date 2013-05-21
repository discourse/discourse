class UploadsController < ApplicationController
  before_filter :ensure_logged_in

  def create
    requires_parameter(:topic_id)
    file = params[:file] || params[:files].first
    # only supports images for now
    return render status: 415, json: failed_json unless file.content_type =~ /^image\/.+/
    upload = Upload.create_for(current_user.id, file, params[:topic_id])
    render_serialized(upload, UploadSerializer, root: false)
  rescue FastImage::ImageFetchFailure
    render status: 422, text: I18n.t("upload.image.fetch_failure")
  rescue FastImage::UnknownImageType
    render status: 422, text: I18n.t("upload.image.unknown_image_type")
  rescue FastImage::SizeNotFound
    render status: 422, text: I18n.t("upload.image.size_not_found")
  end
end
