require_dependency 'upload_creator'

class UploadsController < ApplicationController
  before_filter :ensure_logged_in, except: [:show]
  skip_before_filter :preload_json, :check_xhr, :redirect_to_login_if_required, only: [:show]

  def create
    # 50 characters ought to be enough for the upload type
    type = params.require(:type).parameterize("_")[0..50]

    if type == "avatar" && (SiteSetting.sso_overrides_avatar || !SiteSetting.allow_uploaded_avatars)
      return render json: failed_json, status: 422
    end

    url  = params[:url]
    file = params[:file] || params[:files]&.first
    for_private_message = params[:for_private_message]

    if params[:synchronous] && (current_user.staff? || is_api?)
      data = create_upload(file, url, type, for_private_message)
      render json: data.as_json
    else
      Scheduler::Defer.later("Create Upload") do
        begin
          data = create_upload(file, url, type, for_private_message)
        ensure
          MessageBus.publish("/uploads/#{type}", (data || {}).as_json, client_ids: [params[:client_id]])
        end
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
        opts = {
          filename: upload.original_filename,
          content_type: Rack::Mime.mime_type(File.extname(upload.original_filename)),
        }
        opts[:disposition]   = "inline" if params[:inline]
        opts[:disposition] ||= "attachment" unless FileHelper.is_image?(upload.original_filename)
        send_file(Discourse.store.path_for(upload), opts)
      else
        render_404
      end
    end
  end

  protected

  def render_404
    raise Discourse::NotFound
  end

  def create_upload(file, url, type, for_private_message = false)
    if file.nil?
      if url.present? && is_api?
        maximum_upload_size = [SiteSetting.max_image_size_kb, SiteSetting.max_attachment_size_kb].max.kilobytes
        tempfile = FileHelper.download(
          url,
          max_file_size: maximum_upload_size,
          tmp_file_name: "discourse-upload-#{type}"
        ) rescue nil
        filename = File.basename(URI.parse(url).path)
      end
    else
      tempfile = file.tempfile
      filename = file.original_filename
      content_type = file.content_type
    end

    return { errors: [I18n.t("upload.file_missing")] } if tempfile.nil?

    opts = { type: type, content_type: content_type }
    opts[:for_private_message] = true if for_private_message

    upload = UploadCreator.new(tempfile, filename, opts).create_for(current_user.id)

    if upload.errors.empty? && current_user.admin?
      retain_hours = params[:retain_hours].to_i
      upload.update_columns(retain_hours: retain_hours) if retain_hours > 0
    end

    upload.errors.empty? ? upload : { errors: upload.errors.values.flatten }
  ensure
    tempfile&.close! rescue nil
  end

end
