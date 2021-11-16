# frozen_string_literal: true

require "mini_mime"

class UploadsController < ApplicationController
  requires_login except: [:show, :show_short, :show_secure]

  skip_before_action :preload_json, :check_xhr, :redirect_to_login_if_required, only: [:show, :show_short, :show_secure]
  protect_from_forgery except: :show

  before_action :is_asset_path, :apply_cdn_headers, only: [:show, :show_short, :show_secure]
  before_action :external_store_check, only: [
    :show_secure,
    :generate_presigned_put,
    :complete_external_upload,
    :create_multipart,
    :batch_presign_multipart_parts,
    :abort_multipart,
    :complete_multipart
  ]
  before_action :direct_s3_uploads_check, only: [
    :generate_presigned_put,
    :complete_external_upload,
    :create_multipart,
    :batch_presign_multipart_parts,
    :abort_multipart,
    :complete_multipart
  ]
  before_action :can_upload_external?, only: [:create_multipart, :generate_presigned_put]

  SECURE_REDIRECT_GRACE_SECONDS = 5
  PRESIGNED_PUT_RATE_LIMIT_PER_MINUTE = 10
  CREATE_MULTIPART_RATE_LIMIT_PER_MINUTE = 10
  COMPLETE_MULTIPART_RATE_LIMIT_PER_MINUTE = 10
  BATCH_PRESIGN_RATE_LIMIT_PER_MINUTE = 10

  def create
    # capture current user for block later on
    me = current_user

    params.permit(:type, :upload_type)
    if params[:type].blank? && params[:upload_type].blank?
      raise Discourse::InvalidParameters
    end
    # 50 characters ought to be enough for the upload type
    type = (params[:upload_type].presence || params[:type].presence).parameterize(separator: "_")[0..50]

    if type == "avatar" && !me.admin? && (SiteSetting.discourse_connect_overrides_avatar || !TrustLevelAndStaffAndDisabledSetting.matches?(SiteSetting.allow_uploaded_avatars, me))
      return render json: failed_json, status: 422
    end

    url    = params[:url]
    file   = params[:file] || params[:files]&.first
    pasted = params[:pasted] == "true"
    for_private_message = params[:for_private_message] == "true"
    for_site_setting = params[:for_site_setting] == "true"
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
          for_site_setting: for_site_setting,
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
      PrettyText::Helpers.lookup_upload_urls(params[:short_urls]).each do |short_url, paths|
        uploads << {
          short_url: short_url,
          url: paths[:url],
          short_path: paths[:short_path]
        }
      end
    end

    render json: uploads.to_json
  end

  def show
    # do not serve uploads requested via XHR to prevent XSS
    return xhr_not_allowed if request.xhr?

    return render_404 if !RailsMultisite::ConnectionManagement.has_db?(params[:site])

    RailsMultisite::ConnectionManagement.with_connection(params[:site]) do |db|
      return render_404 if SiteSetting.prevent_anons_from_downloading_files && current_user.nil?

      if upload = Upload.find_by(sha1: params[:sha]) || Upload.find_by(id: params[:id], url: request.env["PATH_INFO"])
        unless Discourse.store.internal?
          local_store = FileStore::LocalStore.new
          return render_404 unless local_store.has_been_uploaded?(upload.url)
        end

        send_file_local_upload(upload)
      else
        render_404
      end
    end
  end

  def show_short
    # do not serve uploads requested via XHR to prevent XSS
    return xhr_not_allowed if request.xhr?

    if SiteSetting.prevent_anons_from_downloading_files && current_user.nil?
      return render_404
    end

    sha1 = Upload.sha1_from_base62_encoded(params[:base62])

    if upload = Upload.find_by(sha1: sha1)
      if upload.secure? && SiteSetting.secure_media?
        return handle_secure_upload_request(upload)
      end

      if Discourse.store.internal?
        send_file_local_upload(upload)
      else
        redirect_to Discourse.store.url_for(upload, force_download: force_download?)
      end
    else
      render_404
    end
  end

  def show_secure
    # do not serve uploads requested via XHR to prevent XSS
    return xhr_not_allowed if request.xhr?

    path_with_ext = "#{params[:path]}.#{params[:extension]}"

    sha1 = File.basename(path_with_ext, File.extname(path_with_ext))
    # this takes care of optimized image requests
    sha1 = sha1.partition("_").first if sha1.include?("_")

    upload = Upload.find_by(sha1: sha1)
    return render_404 if upload.blank?

    return render_404 if SiteSetting.prevent_anons_from_downloading_files && current_user.nil?
    return handle_secure_upload_request(upload, path_with_ext) if SiteSetting.secure_media?

    # we don't want to 404 here if secure media gets disabled
    # because all posts with secure uploads will show broken media
    # until rebaked, which could take some time
    #
    # if the upload is still secure, that means the ACL is probably still
    # private, so we don't want to go to the CDN url just yet otherwise we
    # will get a 403. if the upload is not secure we assume the ACL is public
    signed_secure_url = Discourse.store.signed_url_for_path(path_with_ext)
    redirect_to upload.secure? ? signed_secure_url : Discourse.store.cdn_url(upload.url)
  end

  def handle_secure_upload_request(upload, path_with_ext = nil)
    if upload.access_control_post_id.present?
      raise Discourse::InvalidAccess if !guardian.can_see?(upload.access_control_post)
    else
      return render_404 if current_user.nil?
    end

    # defaults to public: false, so only cached by the client browser
    cache_seconds = S3Helper::DOWNLOAD_URL_EXPIRES_AFTER_SECONDS - SECURE_REDIRECT_GRACE_SECONDS
    expires_in cache_seconds.seconds

    # url_for figures out the full URL, handling multisite DBs,
    # and will return a presigned URL for the upload
    if path_with_ext.blank?
      return redirect_to Discourse.store.url_for(upload, force_download: force_download?)
    end

    redirect_to Discourse.store.signed_url_for_path(
      path_with_ext,
      expires_in: S3Helper::DOWNLOAD_URL_EXPIRES_AFTER_SECONDS,
      force_download: force_download?
    )
  end

  def metadata
    params.require(:url)
    upload = Upload.get_from_url(params[:url])
    raise Discourse::NotFound unless upload

    render json: {
      original_filename: upload.original_filename,
      width: upload.width,
      height: upload.height,
      human_filesize: upload.human_filesize
    }
  end

  def generate_presigned_put
    RateLimiter.new(
      current_user, "generate-presigned-put-upload-stub", PRESIGNED_PUT_RATE_LIMIT_PER_MINUTE, 1.minute
    ).performed!

    file_name = params.require(:file_name)
    file_size = params.require(:file_size).to_i
    type = params.require(:type)

    if file_size_too_big?(file_name, file_size)
      return render_json_error(
        I18n.t("upload.attachments.too_large_humanized", max_size: ActiveSupport::NumberHelper.number_to_human_size(SiteSetting.max_attachment_size_kb.kilobytes)),
        status: 422
      )
    end

    external_upload_data = ExternalUploadManager.create_direct_upload(
      current_user: current_user,
      file_name: file_name,
      file_size: file_size,
      upload_type: type,
      metadata: parse_allowed_metadata(params[:metadata])
    )

    render json: external_upload_data
  end

  def complete_external_upload
    unique_identifier = params.require(:unique_identifier)
    external_upload_stub = ExternalUploadStub.find_by(
      unique_identifier: unique_identifier, created_by: current_user
    )
    return render_404 if external_upload_stub.blank?

    complete_external_upload_via_manager(external_upload_stub)
  end

  def complete_external_upload_via_manager(external_upload_stub)
    opts = {
      for_private_message: params[:for_private_message]&.to_s == "true",
      for_site_setting: params[:for_site_setting]&.to_s == "true",
      pasted: params[:pasted]&.to_s == "true",
    }

    external_upload_manager = ExternalUploadManager.new(external_upload_stub, opts)
    hijack do
      begin
        upload = external_upload_manager.transform!

        if upload.errors.empty?
          response_serialized = external_upload_stub.upload_type != "backup" ? UploadsController.serialize_upload(upload) : {}
          external_upload_stub.destroy!
          render json: response_serialized, status: 200
        else
          render_json_error(upload.errors.to_hash.values.flatten, status: 422)
        end
      rescue ExternalUploadManager::SizeMismatchError => err
        render_json_error(
          debug_upload_error(err, "upload.size_mismatch_failure", additional_detail: err.message),
          status: 422
        )
      rescue ExternalUploadManager::ChecksumMismatchError => err
        render_json_error(
          debug_upload_error(err, "upload.checksum_mismatch_failure", additional_detail: err.message),
          status: 422
        )
      rescue ExternalUploadManager::CannotPromoteError => err
        render_json_error(
          debug_upload_error(err, "upload.cannot_promote_failure", additional_detail: err.message),
          status: 422
        )
      rescue ExternalUploadManager::DownloadFailedError, Aws::S3::Errors::NotFound => err
        render_json_error(
          debug_upload_error(err, "upload.download_failure", additional_detail: err.message),
          status: 422
        )
      rescue => err
        Discourse.warn_exception(
          err, message: "Complete external upload failed unexpectedly for user #{current_user.id}"
        )

        render_json_error(I18n.t("upload.failed"), status: 422)
      end
    end
  end

  def create_multipart
    RateLimiter.new(
      current_user, "create-multipart-upload", CREATE_MULTIPART_RATE_LIMIT_PER_MINUTE, 1.minute
    ).performed!

    file_name = params.require(:file_name)
    file_size = params.require(:file_size).to_i
    upload_type = params.require(:upload_type)

    if upload_type == "backup"
      ensure_staff
      return render_json_error(I18n.t("backup.backup_file_should_be_tar_gz")) unless valid_backup_extension?(file_name)
      return render_json_error(I18n.t("backup.invalid_filename")) unless valid_backup_filename?(file_name)
    else
      if file_size_too_big?(file_name, file_size)
        return render_json_error(
          I18n.t("upload.attachments.too_large_humanized", max_size: ActiveSupport::NumberHelper.number_to_human_size(SiteSetting.max_attachment_size_kb.kilobytes)),
          status: 422
        )
      end
    end

    begin
      external_upload_data = ExternalUploadManager.create_direct_multipart_upload(
        current_user: current_user,
        file_name: file_name,
        file_size: file_size,
        upload_type: upload_type,
        metadata: parse_allowed_metadata(params[:metadata])
      )
    rescue Aws::S3::Errors::ServiceError => err
      return render_json_error(
        debug_upload_error(err, "upload.create_multipart_failure", additional_detail: err.message),
        status: 422
      )
    rescue BackupRestore::BackupStore::BackupFileExists
      return render_json_error(I18n.t("backup.file_exists"), status: 422)
    rescue BackupRestore::BackupStore::StorageError => err
      return render_json_error(
        debug_upload_error(err, "upload.create_multipart_failure", additional_detail: err.message),
        status: 422
      )
    end

    render json: external_upload_data
  end

  def batch_presign_multipart_parts
    part_numbers = params.require(:part_numbers)
    unique_identifier = params.require(:unique_identifier)

    RateLimiter.new(
      current_user, "batch-presign", BATCH_PRESIGN_RATE_LIMIT_PER_MINUTE, 1.minute
    ).performed!

    part_numbers = part_numbers.map do |part_number|
      validate_part_number(part_number)
    end

    external_upload_stub = ExternalUploadStub.find_by(
      unique_identifier: unique_identifier, created_by: current_user
    )
    return render_404 if external_upload_stub.blank?

    if !multipart_upload_exists?(external_upload_stub)
      return render_404
    end

    store = multipart_store(external_upload_stub.upload_type)

    presigned_urls = {}
    part_numbers.each do |part_number|
      presigned_urls[part_number] = store.presign_multipart_part(
        upload_id: external_upload_stub.external_upload_identifier,
        key: external_upload_stub.key,
        part_number: part_number
      )
    end

    render json: { presigned_urls: presigned_urls }
  end

  def validate_part_number(part_number)
    part_number = part_number.to_i
    if !part_number.between?(1, 10000)
      raise Discourse::InvalidParameters.new(
        "Each part number should be between 1 and 10000"
      )
    end
    part_number
  end

  def multipart_upload_exists?(external_upload_stub)
    store = multipart_store(external_upload_stub.upload_type)
    begin
      store.list_multipart_parts(
        upload_id: external_upload_stub.external_upload_identifier,
        key: external_upload_stub.key,
        max_parts: 1
      )
    rescue Aws::S3::Errors::NoSuchUpload => err
      debug_upload_error(err, "upload.external_upload_not_found", { additional_detail: "path: #{external_upload_stub.key}" })
      return false
    end
    true
  end

  def abort_multipart
    external_upload_identifier = params.require(:external_upload_identifier)
    external_upload_stub = ExternalUploadStub.find_by(
      external_upload_identifier: external_upload_identifier
    )

    # The stub could have already been deleted by an earlier error via
    # ExternalUploadManager, so we consider this a great success if the
    # stub is already gone.
    return render json: success_json if external_upload_stub.blank?

    return render_404 if external_upload_stub.created_by_id != current_user.id
    store = multipart_store(external_upload_stub.upload_type)

    begin
      store.abort_multipart(
        upload_id: external_upload_stub.external_upload_identifier,
        key: external_upload_stub.key
      )
    rescue Aws::S3::Errors::ServiceError => err
      return render_json_error(
        debug_upload_error(err, "upload.abort_multipart_failure", additional_detail: "external upload stub id: #{external_upload_stub.id}"),
        status: 422
      )
    end

    external_upload_stub.destroy!

    render json: success_json
  end

  def complete_multipart
    unique_identifier = params.require(:unique_identifier)
    parts = params.require(:parts)

    RateLimiter.new(
      current_user, "complete-multipart-upload", COMPLETE_MULTIPART_RATE_LIMIT_PER_MINUTE, 1.minute
    ).performed!

    external_upload_stub = ExternalUploadStub.find_by(
      unique_identifier: unique_identifier, created_by: current_user
    )
    return render_404 if external_upload_stub.blank?

    if !multipart_upload_exists?(external_upload_stub)
      return render_404
    end

    store = multipart_store(external_upload_stub.upload_type)
    parts = parts.map do |part|
      part_number = part[:part_number]
      etag = part[:etag]
      part_number = validate_part_number(part_number)

      if etag.blank?
        raise Discourse::InvalidParameters.new("All parts must have an etag and a valid part number")
      end

      # this is done so it's an array of hashes rather than an array of
      # ActionController::Parameters
      { part_number: part_number, etag: etag }
    end.sort_by do |part|
      part[:part_number]
    end

    begin
      complete_response = store.complete_multipart(
        upload_id: external_upload_stub.external_upload_identifier,
        key: external_upload_stub.key,
        parts: parts
      )
    rescue Aws::S3::Errors::ServiceError => err
      return render_json_error(
        debug_upload_error(err, "upload.complete_multipart_failure", additional_detail: "external upload stub id: #{external_upload_stub.id}"),
        status: 422
      )
    end

    complete_external_upload_via_manager(external_upload_stub)
  end

  protected

  def multipart_store(upload_type)
    ensure_staff if upload_type == "backup"
    ExternalUploadManager.store_for_upload_type(upload_type)
  end

  def force_download?
    params[:dl] == "1"
  end

  def xhr_not_allowed
    raise Discourse::InvalidParameters.new("XHR not allowed")
  end

  def render_404
    raise Discourse::NotFound
  end

  def self.serialize_upload(data)
    # as_json.as_json is not a typo... as_json in AM serializer returns keys as symbols, we need them
    # as strings here
    serialized = UploadSerializer.new(data, root: nil).as_json.as_json if Upload === data
    serialized ||= (data || {}).as_json
  end

  def self.create_upload(current_user:,
                         file:,
                         url:,
                         type:,
                         for_private_message:,
                         for_site_setting:,
                         pasted:,
                         is_api:,
                         retain_hours:)

    if file.nil?
      if url.present? && is_api
        maximum_upload_size = [SiteSetting.max_image_size_kb, SiteSetting.max_attachment_size_kb].max.kilobytes
        tempfile = FileHelper.download(
          url,
          follow_redirect: true,
          max_file_size: maximum_upload_size,
          tmp_file_name: "discourse-upload-#{type}"
        ) rescue nil
        filename = File.basename(URI.parse(url).path)
      end
    else
      tempfile = file.tempfile
      filename = file.original_filename
    end

    return { errors: [I18n.t("upload.file_missing")] } if tempfile.nil?

    opts = {
      type: type,
      for_private_message: for_private_message,
      for_site_setting: for_site_setting,
      pasted: pasted,
    }

    upload = UploadCreator.new(tempfile, filename, opts).create_for(current_user.id)

    if upload.errors.empty? && current_user.admin?
      upload.update_columns(retain_hours: retain_hours) if retain_hours > 0
    end

    upload.errors.empty? ? upload : { errors: upload.errors.to_hash.values.flatten }
  ensure
    tempfile&.close!
  end

  private

  def external_store_check
    return render_404 if !Discourse.store.external?
  end

  def direct_s3_uploads_check
    return render_404 if !SiteSetting.enable_direct_s3_uploads
  end

  def can_upload_external?
    raise Discourse::InvalidAccess if !guardian.can_upload_external?
  end

  # We can pre-emptively check size for attachments, but not for images
  # as they may be further reduced in size by UploadCreator (at this point
  # they may have already been reduced in size by preprocessors)
  def file_size_too_big?(file_name, file_size)
    !FileHelper.is_supported_image?(file_name) && file_size >= SiteSetting.max_attachment_size_kb.kilobytes
  end

  def send_file_local_upload(upload)
    opts = {
      filename: upload.original_filename,
      content_type: MiniMime.lookup_by_filename(upload.original_filename)&.content_type
    }

    if !FileHelper.is_inline_image?(upload.original_filename)
      opts[:disposition] = "attachment"
    elsif params[:inline]
      opts[:disposition] = "inline"
    end

    file_path = Discourse.store.path_for(upload)
    return render_404 unless file_path

    send_file(file_path, opts)
  end

  def debug_upload_error(err, translation_key, translation_params = {})
    return if !SiteSetting.enable_upload_debug_mode
    message = I18n.t(translation_key, translation_params)
    Discourse.warn_exception(err, message: message)
    Rails.env.development? ? message : I18n.t("upload.failed")
  end

  # don't want people posting arbitrary S3 metadata so we just take the
  # one we need. all of these will be converted to x-amz-meta- metadata
  # fields in S3 so it's best to use dashes in the names for consistency
  #
  # this metadata is baked into the presigned url and is not altered when
  # sending the PUT from the clientside to the presigned url
  def parse_allowed_metadata(metadata)
    return if metadata.blank?
    metadata.permit("sha1-checksum").to_h
  end

  def valid_backup_extension?(filename)
    /\.(tar\.gz|t?gz)$/i =~ filename
  end

  def valid_backup_filename?(filename)
    !!(/^[a-zA-Z0-9\._\-]+$/ =~ filename)
  end
end
