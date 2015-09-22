class UploadsController < ApplicationController
  before_filter :ensure_logged_in, except: [:show]
  skip_before_filter :preload_json, :check_xhr, :redirect_to_login_if_required, only: [:show]

  def create
    type = params.require(:type)
    file = params[:file] || params[:files].try(:first)
    url = params[:url]
    client_id = params[:client_id]
    synchronous = is_api? && params[:synchronous]

    # HACK FOR IE9 to prevent the "download dialog"
    response.headers["Content-Type"] = "text/plain" if request.user_agent =~ /MSIE 9/

    if synchronous
      data = create_upload(type, file, url)
      render json: data.as_json
    else
      Scheduler::Defer.later("Create Upload") do
        data = create_upload(type, file, url)
        MessageBus.publish("/uploads/#{type}", data.as_json, client_ids: [client_id])
      end
      render json: success_json
    end
  end

  def show
    return render_404 if !RailsMultisite::ConnectionManagement.has_db?(params[:site])

    RailsMultisite::ConnectionManagement.with_connection(params[:site]) do |db|
      return render_404 unless Discourse.store.internal?
      return render_404 if SiteSetting.prevent_anons_from_downloading_files && current_user.nil?
      return render_404 if SiteSetting.login_required? && db == "default" && current_user.nil?

      if upload = Upload.find_by(sha1: params[:sha]) || Upload.find_by(id: params[:id], url: request.env["PATH_INFO"])
        opts = { filename: upload.original_filename }
        opts[:disposition] = 'inline' if params[:inline]
        send_file(Discourse.store.path_for(upload), opts)
      else
        render_404
      end
    end
  end

  protected

  def render_404
    render nothing: true, status: 404
  end

  def create_upload(type, file, url)
    begin
      # ensure we have a file
      if file.nil?
        # API can provide a URL
        if url.present? && is_api?
          tempfile = FileHelper.download(url, 10.megabytes, "discourse-upload-#{type}") rescue nil
          filename = File.basename(URI.parse(url).path)
        end
      else
        tempfile = file.tempfile
        filename = file.original_filename
        content_type = file.content_type
      end

      return { errors: I18n.t("upload.file_missing") } if tempfile.nil?

      # allow users to upload large images that will be automatically reduced to allowed size
      if SiteSetting.max_image_size_kb > 0 && FileHelper.is_image?(filename) && File.size(tempfile.path) > 0
        allow_animation = type == "avatar" ? SiteSetting.allow_animated_avatars : SiteSetting.allow_animated_thumbnails
        attempt = 5
        while attempt > 0 && File.size(tempfile.path) > SiteSetting.max_image_size_kb.kilobytes
          OptimizedImage.downsize(tempfile.path, tempfile.path, "80%", filename: filename, allow_animation: allow_animation)
          attempt -= 1
        end
      end

      upload = Upload.create_for(current_user.id, tempfile, filename, File.size(tempfile.path), content_type: content_type, image_type: type)

      if upload.errors.empty? && current_user.admin?
        retain_hours = params[:retain_hours].to_i
        upload.update_columns(retain_hours: retain_hours) if retain_hours > 0
      end

      if upload.errors.empty? && FileHelper.is_image?(filename)
        Jobs.enqueue(:create_thumbnails, upload_id: upload.id, type: type, user_id: params[:user_id])
      end

      upload.errors.empty? ? upload : { errors: upload.errors.values.flatten }
    ensure
      tempfile.try(:close!) rescue nil
    end
  end

end
