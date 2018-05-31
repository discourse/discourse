require "mini_mime"
require_dependency 'upload_creator'

class UploadsController < ApplicationController
  requires_login except: [:show]

  skip_before_action :preload_json, :check_xhr, :redirect_to_login_if_required, only: [:show]

  def create
    # capture current user for block later on
    me = current_user

    # 50 characters ought to be enough for the upload type
    type = params.require(:type).parameterize(separator: "_")[0..50]

    if type == "avatar" && (SiteSetting.sso_overrides_avatar || !SiteSetting.allow_uploaded_avatars)
      return render json: failed_json, status: 422
    end

    url    = params[:url]
    file   = params[:file] || params[:files]&.first
    pasted = params[:pasted] == "true"
    for_private_message = params[:for_private_message] == "true"
    is_api = is_api?
    retain_hours = params[:retain_hours].to_i

    # note, atm hijack is processed in its own context and has not access to controller
    # longer term we may change this
    hijack do
      begin
        info = UploadsController.create_upload(
          current_user: me,
          file: file,
          url: url,
          type: type,
          for_private_message: for_private_message,
          pasted: pasted,
          is_api: is_api,
          retain_hours: retain_hours
        )
      rescue => e
        render json: failed_json.merge(message: e.message&.split("\n")&.first), status: 422
      else
        render json: UploadsController.serialize_upload(info), status: Upload === info ? 200 : 422
      end
    end
  end

  def lookup_urls
    params.permit(short_urls: [])
    uploads = []

    if (params[:short_urls] && params[:short_urls].length > 0)
      PrettyText::Helpers.lookup_image_urls(params[:short_urls]).each do |short_url, url|
        uploads << { short_url: short_url, url: url }
      end
    end

    render json: uploads.to_json
  end

  def show
    return render_404 if !RailsMultisite::ConnectionManagement.has_db?(params[:site])

    RailsMultisite::ConnectionManagement.with_connection(params[:site]) do |db|
      return render_404 unless Discourse.store.internal?
      return render_404 if SiteSetting.prevent_anons_from_downloading_files && current_user.nil?

      if upload = Upload.find_by(sha1: params[:sha]) || Upload.find_by(id: params[:id], url: request.env["PATH_INFO"])
        opts = {
          filename: upload.original_filename,
          content_type: MiniMime.lookup_by_filename(upload.original_filename)&.content_type,
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

  def self.serialize_upload(data)
    # as_json.as_json is not a typo... as_json in AM serializer returns keys as symbols, we need them
    # as strings here
    serialized = UploadSerializer.new(data, root: nil).as_json.as_json if Upload === data
    serialized ||= (data || {}).as_json
  end

  def self.create_upload(current_user:, file:, url:, type:, for_private_message:, pasted:, is_api:, retain_hours:)
    if file.nil?
      if url.present? && is_api
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

    opts = {
      type: type,
      content_type: content_type,
      for_private_message: for_private_message,
      pasted: pasted,
    }

    upload = UploadCreator.new(tempfile, filename, opts).create_for(current_user.id)

    if upload.errors.empty? && current_user.admin?
      upload.update_columns(retain_hours: retain_hours) if retain_hours > 0
    end

    upload.errors.empty? ? upload : { errors: upload.errors.values.flatten }
  ensure
    tempfile&.close!
  end

end
