# frozen_string_literal: true

class ExternalUploadManager
  DOWNLOAD_LIMIT = 100.megabytes
  SIZE_MISMATCH_BAN_MINUTES = 5
  BAN_USER_REDIS_PREFIX = "ban_user_from_external_uploads_"

  UPLOAD_TYPES_EXCLUDED_FROM_UPLOAD_PROMOTION = ["backup"].freeze

  class ChecksumMismatchError < StandardError
  end
  class DownloadFailedError < StandardError
  end
  class CannotPromoteError < StandardError
  end
  class SizeMismatchError < StandardError
  end

  attr_reader :external_upload_stub

  def self.ban_user_from_external_uploads!(user:, ban_minutes: 5)
    Discourse.redis.setex("#{BAN_USER_REDIS_PREFIX}#{user.id}", ban_minutes.minutes.to_i, "1")
  end

  def self.user_banned?(user)
    Discourse.redis.get("#{BAN_USER_REDIS_PREFIX}#{user.id}") == "1"
  end

  def self.create_direct_upload(current_user:, file_name:, file_size:, upload_type:, metadata: {})
    store = store_for_upload_type(upload_type)
    url = store.signed_url_for_temporary_upload(file_name, metadata: metadata)
    key = store.s3_helper.path_from_url(url)

    upload_stub =
      ExternalUploadStub.create!(
        # TODO (martin): Need to figure out a better way of doing this; the key is
        # doubling up the bucket in the path and we don't want to store it in the
        # DB that way.
        key: key.gsub("#{SiteSetting.s3_upload_bucket}/", ""),
        created_by: current_user,
        original_filename: file_name,
        upload_type: upload_type,
        filesize: file_size,
      )

    { url: url, key: key, unique_identifier: upload_stub.unique_identifier }
  end

  def self.create_direct_multipart_upload(
    current_user:,
    file_name:,
    file_size:,
    upload_type:,
    metadata: {}
  )
    content_type = MiniMime.lookup_by_filename(file_name)&.content_type
    store = store_for_upload_type(upload_type)
    multipart_upload = store.create_multipart(file_name, content_type, metadata: metadata)

    upload_stub =
      ExternalUploadStub.create!(
        key: multipart_upload[:key],
        created_by: current_user,
        original_filename: file_name,
        upload_type: upload_type,
        external_upload_identifier: multipart_upload[:upload_id],
        multipart: true,
        filesize: file_size,
      )

    {
      external_upload_identifier: upload_stub.external_upload_identifier,
      key: upload_stub.key,
      unique_identifier: upload_stub.unique_identifier,
    }
  end

  def self.store_for_upload_type(upload_type)
    if upload_type == "backup"
      if !SiteSetting.enable_backups? ||
           SiteSetting.backup_location != BackupLocationSiteSetting::S3
        raise Discourse::InvalidAccess.new
      end
      BackupRestore::BackupStore.create
    else
      Discourse.store
    end
  end

  def initialize(external_upload_stub, upload_create_opts = {})
    @external_upload_stub = external_upload_stub
    @upload_create_opts = upload_create_opts
    @store = ExternalUploadManager.store_for_upload_type(external_upload_stub.upload_type)
  end

  def can_promote?
    external_upload_stub.status == ExternalUploadStub.statuses[:created]
  end

  def transform!
    raise CannotPromoteError if !can_promote?
    external_upload_stub.update!(status: ExternalUploadStub.statuses[:uploaded])

    # We require that the file size is specified ahead of time, and compare
    # it here to make sure that people are not uploading excessively large
    # files to the external provider. If this happens, the user will be banned
    # from uploading to the external provider for N minutes.
    if external_size != external_upload_stub.filesize
      ExternalUploadManager.ban_user_from_external_uploads!(
        user: external_upload_stub.created_by,
        ban_minutes: SIZE_MISMATCH_BAN_MINUTES,
      )
      raise SizeMismatchError.new(
              "expected: #{external_upload_stub.filesize}, actual: #{external_size}",
            )
    end

    if UPLOAD_TYPES_EXCLUDED_FROM_UPLOAD_PROMOTION.include?(external_upload_stub.upload_type)
      move_to_final_destination
    else
      promote_to_upload
    end
  rescue StandardError
    if !SiteSetting.enable_upload_debug_mode
      # We don't need to do anything special to abort multipart uploads here,
      # because at this point (calling promote_to_upload!), the multipart
      # upload would already be complete.
      @store.delete_file(external_upload_stub.key)
      external_upload_stub.destroy!
    else
      external_upload_stub.update(status: ExternalUploadStub.statuses[:failed])
    end

    raise
  end

  private

  def promote_to_upload
    # This could be legitimately nil, if it's too big to download on the
    # server, or it could have failed. To this end we set a should_download
    # variable as well to check.
    tempfile = nil
    should_download = external_size < DOWNLOAD_LIMIT

    if should_download
      tempfile = download(external_upload_stub.key, external_upload_stub.upload_type)

      raise DownloadFailedError if tempfile.blank?

      actual_sha1 = Upload.generate_digest(tempfile)
      raise ChecksumMismatchError if external_sha1 && external_sha1 != actual_sha1
    end

    opts = {
      type: external_upload_stub.upload_type,
      existing_external_upload_key: external_upload_stub.key,
      external_upload_too_big: external_size > DOWNLOAD_LIMIT,
      filesize: external_size,
    }.merge(@upload_create_opts)

    UploadCreator.new(tempfile, external_upload_stub.original_filename, opts).create_for(
      external_upload_stub.created_by_id,
    )
  ensure
    tempfile&.close!
  end

  def move_to_final_destination
    content_type = MiniMime.lookup_by_filename(external_upload_stub.original_filename).content_type
    @store.move_existing_stored_upload(
      existing_external_upload_key: external_upload_stub.key,
      original_filename: external_upload_stub.original_filename,
      content_type: content_type,
    )
    Struct.new(:errors).new([])
  end

  def external_stub_object
    @external_stub_object ||= @store.object_from_path(external_upload_stub.key)
  end

  def external_etag
    @external_etag ||= external_stub_object.etag
  end

  def external_size
    @external_size ||= external_stub_object.size
  end

  def external_sha1
    @external_sha1 ||= external_stub_object.metadata["sha1-checksum"]
  end

  def download(key, type)
    url = @store.signed_url_for_path(external_upload_stub.key)
    FileHelper.download(
      url,
      max_file_size: DOWNLOAD_LIMIT,
      tmp_file_name: "discourse-upload-#{type}",
      follow_redirect: true,
      # TODO (martin): Had to do this because FinalDestination enforces certain ports based
      # on URI scheme, probably a better way.
      validate_uri: false,
    )
  end
end
