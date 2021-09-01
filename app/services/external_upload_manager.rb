# frozen_string_literal: true

class ExternalUploadManager
  DOWNLOAD_LIMIT = 100.megabytes
  SIZE_MISMATCH_BAN_MINUTES = 5
  BAN_USER_REDIS_PREFIX = "ban_user_from_external_uploads_"

  class ChecksumMismatchError < StandardError; end
  class DownloadFailedError < StandardError; end
  class CannotPromoteError < StandardError; end
  class SizeMismatchError < StandardError; end

  attr_reader :external_upload_stub

  def self.ban_user_from_external_uploads!(user:, ban_minutes: 5)
    Discourse.redis.setex("#{BAN_USER_REDIS_PREFIX}#{user.id}", ban_minutes.minutes.to_i, "1")
  end

  def self.user_banned?(user)
    Discourse.redis.get("#{BAN_USER_REDIS_PREFIX}#{user.id}") == "1"
  end

  def initialize(external_upload_stub)
    @external_upload_stub = external_upload_stub
  end

  def can_promote?
    external_upload_stub.status == ExternalUploadStub.statuses[:created]
  end

  def promote_to_upload!
    raise CannotPromoteError if !can_promote?

    external_upload_stub.update!(status: ExternalUploadStub.statuses[:uploaded])
    external_stub_object = Discourse.store.object_from_path(external_upload_stub.key)
    external_etag = external_stub_object.etag
    external_size = external_stub_object.size
    external_sha1 = external_stub_object.metadata["sha1-checksum"]

    # This could be legitimately nil, if it's too big to download on the
    # server, or it could have failed. To this end we set a should_download
    # variable as well to check.
    tempfile = nil
    should_download = external_size < DOWNLOAD_LIMIT

    # We require that the file size is specified ahead of time, and compare
    # it here to make sure that people are not uploading excessively large
    # files to the external provider. If this happens, the user will be banned
    # from uploading to the external provider for N minutes.
    if external_size != external_upload_stub.filesize
      ExternalUploadManager.ban_user_from_external_uploads!(
        user: external_upload_stub.created_by,
        ban_minutes: SIZE_MISMATCH_BAN_MINUTES
      )
      raise SizeMismatchError.new("expected: #{external_upload_stub.filesize}, actual: #{external_size}")
    end

    if should_download
      tempfile = download(external_upload_stub.key, external_upload_stub.upload_type)

      raise DownloadFailedError if tempfile.blank?

      actual_sha1 = Upload.generate_digest(tempfile)
      if external_sha1 && external_sha1 != actual_sha1
        raise ChecksumMismatchError
      end
    end

    # TODO (martin): See if these additional opts will be needed
    #
    # for_private_message: for_private_message,
    # for_site_setting: for_site_setting,
    # pasted: pasted,
    #
    # also check if retain_hours is needed
    opts = {
      type: external_upload_stub.upload_type,
      existing_external_upload_key: external_upload_stub.key,
      external_upload_too_big: external_size > DOWNLOAD_LIMIT,
      filesize: external_size
    }

    UploadCreator.new(tempfile, external_upload_stub.original_filename, opts).create_for(
      external_upload_stub.created_by_id
    )
  rescue
    if !SiteSetting.enable_upload_debug_mode
      # We don't need to do anything special to abort multipart uploads here,
      # because at this point (calling promote_to_upload!), the multipart
      # upload would already be complete.
      Discourse.store.delete_file(external_upload_stub.key)
      external_upload_stub.destroy!
    else
      external_upload_stub.update(status: ExternalUploadStub.statuses[:failed])
    end

    raise
  ensure
    tempfile&.close!
  end

  private

  def download(key, type)
    url = Discourse.store.signed_url_for_path(external_upload_stub.key)
    FileHelper.download(
      url,
      max_file_size: DOWNLOAD_LIMIT,
      tmp_file_name: "discourse-upload-#{type}",
      follow_redirect: true
    )
  end
end
