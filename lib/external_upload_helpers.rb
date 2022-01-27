# frozen_string_literal: true

# Extends controllers with the methods required to do direct
# external uploads.
module ExternalUploadHelpers
  extend ActiveSupport::Concern

  class ExternalUploadValidationError < StandardError; end

  PRESIGNED_PUT_RATE_LIMIT_PER_MINUTE = 10
  CREATE_MULTIPART_RATE_LIMIT_PER_MINUTE = 10
  COMPLETE_MULTIPART_RATE_LIMIT_PER_MINUTE = 10
  BATCH_PRESIGN_RATE_LIMIT_PER_MINUTE = 10

  included do
    before_action :external_store_check, only: [
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
  end

  def generate_presigned_put
    RateLimiter.new(
      current_user, "generate-presigned-put-upload-stub", ExternalUploadHelpers::PRESIGNED_PUT_RATE_LIMIT_PER_MINUTE, 1.minute
    ).performed!

    file_name = params.require(:file_name)
    file_size = params.require(:file_size).to_i
    type = params.require(:type)

    begin
      validate_before_create_direct_upload(
        file_name: file_name,
        file_size: file_size,
        upload_type: type
      )
    rescue ExternalUploadValidationError => err
      return render_json_error(err.message, status: 422)
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

  def create_multipart
    RateLimiter.new(
      current_user, "create-multipart-upload", ExternalUploadHelpers::CREATE_MULTIPART_RATE_LIMIT_PER_MINUTE, 1.minute
    ).performed!

    file_name = params.require(:file_name)
    file_size = params.require(:file_size).to_i
    upload_type = params.require(:upload_type)

    begin
      validate_before_create_multipart(
        file_name: file_name,
        file_size: file_size,
        upload_type: upload_type
      )
    rescue ExternalUploadValidationError => err
      return render_json_error(err.message, status: 422)
    end

    begin
      external_upload_data = create_direct_multipart_upload do
        ExternalUploadManager.create_direct_multipart_upload(
          current_user: current_user,
          file_name: file_name,
          file_size: file_size,
          upload_type: upload_type,
          metadata: parse_allowed_metadata(params[:metadata])
        )
      end
    rescue ExternalUploadHelpers::ExternalUploadValidationError => err
      return render_json_error(err.message, status: 422)
    end

    render json: external_upload_data
  end

  def batch_presign_multipart_parts
    part_numbers = params.require(:part_numbers)
    unique_identifier = params.require(:unique_identifier)

    RateLimiter.new(
      current_user, "batch-presign", ExternalUploadHelpers::BATCH_PRESIGN_RATE_LIMIT_PER_MINUTE, 1.minute
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

  def multipart_upload_exists?(external_upload_stub)
    store = multipart_store(external_upload_stub.upload_type)
    begin
      store.list_multipart_parts(
        upload_id: external_upload_stub.external_upload_identifier,
        key: external_upload_stub.key,
        max_parts: 1
      )
    rescue Aws::S3::Errors::NoSuchUpload => err
      debug_upload_error(err, I18n.t("upload.external_upload_not_found", additional_detail: "path: #{external_upload_stub.key}"))
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
        debug_upload_error(err, I18n.t("upload.abort_multipart_failure", additional_detail: "external upload stub id: #{external_upload_stub.id}")),
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
      current_user, "complete-multipart-upload", ExternalUploadHelpers::COMPLETE_MULTIPART_RATE_LIMIT_PER_MINUTE, 1.minute
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
        debug_upload_error(err, I18n.t("upload.complete_multipart_failure", additional_detail: "external upload stub id: #{external_upload_stub.id}")),
        status: 422
      )
    end

    complete_external_upload_via_manager(external_upload_stub)
  end

  private

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
          response_serialized = self.class.serialize_upload(upload)
          external_upload_stub.destroy!
          render json: response_serialized, status: 200
        else
          render_json_error(upload.errors.to_hash.values.flatten, status: 422)
        end
      rescue ExternalUploadManager::SizeMismatchError => err
        render_json_error(
          debug_upload_error(err, I18n.t("upload.size_mismatch_failure", additional_detail: err.message)),
          status: 422
        )
      rescue ExternalUploadManager::ChecksumMismatchError => err
        render_json_error(
          debug_upload_error(err, I18n.t("upload.checksum_mismatch_failure", additional_detail: err.message)),
          status: 422
        )
      rescue ExternalUploadManager::CannotPromoteError => err
        render_json_error(
          debug_upload_error(err, I18n.t("upload.cannot_promote_failure", additional_detail: err.message)),
          status: 422
        )
      rescue ExternalUploadManager::DownloadFailedError, Aws::S3::Errors::NotFound => err
        render_json_error(
          debug_upload_error(err, I18n.t("upload.download_failure", additional_detail: err.message)),
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

  def validate_before_create_direct_upload(file_name:, file_size:, upload_type:)
    # noop, should be overridden
  end

  def validate_before_create_multipart(file_name:, file_size:, upload_type:)
    # noop, should be overridden
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

  def debug_upload_error(err, friendly_message)
    return if !SiteSetting.enable_upload_debug_mode
    Discourse.warn_exception(err, message: friendly_message)
    Rails.env.development? ? friendly_message : I18n.t("upload.failed")
  end

  def multipart_store(upload_type)
    ExternalUploadManager.store_for_upload_type(upload_type)
  end

  def external_store_check
    return render_404 if !Discourse.store.external?
  end

  def direct_s3_uploads_check
    return render_404 if !SiteSetting.enable_direct_s3_uploads
  end

  def can_upload_external?
    raise Discourse::InvalidAccess if !guardian.can_upload_external?
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

  def render_404
    raise Discourse::NotFound
  end
end
