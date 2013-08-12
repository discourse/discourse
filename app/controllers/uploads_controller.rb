class UploadsController < ApplicationController
  before_filter :ensure_logged_in
  
  # Nope! This might be using the iframe transport
  skip_before_filter :verify_authenticity_token
  skip_before_filter :check_xhr

  def create
    file = params[:file] || params[:files].first

    # check if the extension is allowed
    unless SiteSetting.authorized_upload?(file)
      text = I18n.t("upload.unauthorized", authorized_extensions: SiteSetting.authorized_extensions.gsub("|", ", "))
      return render status: 415, text: text
    end

    # check the file size (note: this might also be done in the web server)
    filesize = File.size(file.tempfile)
    type = SiteSetting.authorized_image?(file) ? "image" : "attachment"
    max_size_kb = SiteSetting.send("max_#{type}_size_kb") * 1024
    return render status: 413, text: I18n.t("upload.#{type}s.too_large", max_size_kb: max_size_kb) if filesize > max_size_kb

    upload = Upload.create_for(current_user.id, file, filesize)
    
    if request.xhr?
      render_serialized(upload, UploadSerializer, root: false)
    else
      json = MultiJson.dump(serialize_data(upload, UploadSerializer, root: false))
      render text: "<html><body><textarea data-type=\"application/json\">#{json}</textarea></body></html>"
    end

  rescue FastImage::ImageFetchFailure
    render status: 422, text: I18n.t("upload.images.fetch_failure")
  rescue FastImage::UnknownImageType
    render status: 422, text: I18n.t("upload.images.unknown_image_type")
  rescue FastImage::SizeNotFound
    render status: 422, text: I18n.t("upload.images.size_not_found")
  end

end
