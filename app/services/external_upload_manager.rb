# frozen_string_literal: true

class ExternalUploadManager
  DOWNLOAD_LIMIT = 100.megabytes

  class ChecksumMismatchError < StandardError; end
  class DownloadFailedError < StandardError; end

  attr_reader :external_upload_stub

  def initialize(external_upload_stub)
    @external_upload_stub = external_upload_stub
  end

  def can_promote?
    external_upload_stub.status == ExternalUploadStub.statuses[:created]
  end

  # TODO (martin) Change it so that type is saved with the stub
  def promote_to_upload!(type:)
    external_stub_object = Discourse.store.object_from_key(external_upload_stub.key)
    # Aws::S3::Errors::NotFound in case key has been deleted on S3
    external_etag = external_stub_object.etag
    external_size = external_stub_object.size
    external_sha1 = external_stub_object.metadata["sha1-checksum"]

    # This could be legitimately nil, if it's too big to download on the
    # server, or it could have failed. To this end we set a should_download
    # variable as well to check.
    tempfile = nil
    should_download = external_size < DOWNLOAD_LIMIT
    if should_download
      tempfile = download(external_upload_stub.key, type)

      # download failed ERR
      raise DownloadFailedError if tempfile.blank?

      actual_sha1 = Upload.generate_digest(tempfile)
      if external_sha1 && external_sha1 != actual_sha1
        raise ChecksumMismatchError
      end
    end

    # TODO (martin): See if these additional opts will be needed
    # for_private_message: for_private_message,
    # for_site_setting: for_site_setting,
    # pasted: pasted,
    #
    # also check if retain_hours is needed
    #
    opts = {
      type: type,
      existing_external_upload_key: external_upload_stub.key,
      external_upload_too_big: external_size > DOWNLOAD_LIMIT,
      filesize: external_size
    }

    upload = UploadCreator.new(tempfile, external_upload_stub.original_filename, opts).create_for(
      external_upload_stub.created_by_id
    )
  rescue => err
    external_upload_stub.update!(status: ExternalUploadStub.statuses[:created])
    raise err
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

# promote_to_upload
#
# 1. get object S3, so we can determine file size and etag
# 2. if file size is > 100mb (const) then we do not download, so we have no @file
# 3. if file size is < 100mb we download using FileHelper.download so we do have a @file
# 4. compare md5 checksum from client with etag on s3 (maybe...check this...not sure of multipart)
# 5. create upload
#     * if @file, then all goes normally
#     * if no @file, we meed to skip all of the below and use a fake sha1
# 6. finish and return response
#     * on success, delete the stub
#     * on error, roll back upload stub status to created (or maybe make failed?)
#
# UploadCreator changes for no downloaded file
#
# 1. FastImage cannot be used, we need to know if its an image from amazon?? Also can't use identify -ping command
# 2. No sha1 generation, also probably need some column to indicate fake sha/big file?
# 3. before_upload_creation trigger cannot be used
# 4. store_upload cannot upload to s3, it simply moves the existing file on s3 to the new location
#
# ETags and MD5
#
# Objects created through the AWS Management Console or by the PUT Object, POST Object, or Copy operation:

# Objects encrypted by SSE-S3 or plaintext have ETags that are an MD5 digest of their data.

# Objects encrypted by SSE-C or SSE-KMS have ETags that are not an MD5 digest of their object data.

# Objects created by either the Multipart Upload or Part Copy operation have ETags that are not MD5 digests, regardless of the method of encryption.
#
# tl;dr - multiart upload is not the md5, its an md5 of all the concatenated md5s of the parts. regular uploads the etag is the md5 content. can we do an md5 hash of each part with s3 multipart??
