class UploadsController < ApplicationController
  before_filter :ensure_logged_in

  def create
    file = params[:file] || params[:files].first

    return render status: 415, json: failed_json unless SiteSetting.authorized_file?(file)

    upload = Upload.create_for(current_user.id, file)

    render_serialized(upload, UploadSerializer, root: false)

  rescue FastImage::ImageFetchFailure
    render status: 422, text: I18n.t("upload.image.fetch_failure")
  rescue FastImage::UnknownImageType
    render status: 422, text: I18n.t("upload.image.unknown_image_type")
  rescue FastImage::SizeNotFound
    render status: 422, text: I18n.t("upload.image.size_not_found")
  end

end
