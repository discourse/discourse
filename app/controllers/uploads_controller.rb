class UploadsController < ApplicationController
  before_filter :ensure_logged_in

  def create
    file = params[:file] || params[:files].first

    unless SiteSetting.authorized_upload?(file)
      text = I18n.t("upload.unauthorized", authorized_extensions: SiteSetting.authorized_extensions.gsub("|", ", "))
      return render status: 415, text: text
    end

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
