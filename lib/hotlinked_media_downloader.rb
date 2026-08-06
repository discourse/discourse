# frozen_string_literal: true

# Shared logic for downloading a hotlinked (external) image and turning it into
# a local Upload. Used by the post-side Jobs::PullHotlinkedImages and the
# chat-side Jobs::Chat::PullHotlinkedImages so the download/retry/secure-upload
# handling lives in one place.
class HotlinkedMediaDownloader
  class ImageTooLargeError < StandardError
  end

  class ImageBrokenError < StandardError
  end

  class UploadCreateError < StandardError
  end

  # Downloads +src+ and creates an Upload owned by +user_id+.
  # Returns the persisted Upload or raises one of the typed errors above.
  def self.download(src, user_id, tmp_file_name:)
    new(tmp_file_name).download(src, user_id)
  end

  def initialize(tmp_file_name)
    @tmp_file_name = tmp_file_name
  end

  def download(src, user_id)
    # secure-uploads endpoint prevents anonymous downloads, so we
    # need the presigned S3 URL here
    if Upload.secure_uploads_url?(src)
      src = Upload.signed_url_from_secure_uploads_url(src, include_content_disposition: false)
    end

    file = download_file(src)
    raise ImageBrokenError if !file
    raise ImageTooLargeError if File.size(file.path) > SiteSetting.max_image_size_kb.kilobytes

    filename = File.basename(URI.parse(src).path)
    filename << File.extname(file.path) if !filename["."]
    upload = UploadCreator.new(file, filename, origin: src).create_for(user_id)
    if !upload.persisted?
      raise UploadCreateError,
            "Failed to persist downloaded hotlinked image #{src}: #{upload.errors.full_messages.join(", ")}"
    end
    upload
  end

  private

  def download_file(src)
    downloaded = nil
    retries = 3

    begin
      if SiteSetting.verbose_upload_logging
        Rails.logger.warn("Verbose Upload Logging: Downloading hotlinked image from #{src}")
      end

      downloaded =
        FileHelper.download(
          src,
          max_file_size: SiteSetting.max_image_size_kb.kilobytes,
          retain_on_max_file_size_exceeded: true,
          tmp_file_name: @tmp_file_name,
          follow_redirect: true,
          read_timeout: 15,
        )
    rescue StandardError => e
      if SiteSetting.verbose_upload_logging
        Rails.logger.warn("Verbose Upload Logging: Error '#{e.message}' while downloading #{src}")
      end

      if (retries -= 1) > 0 && !Rails.env.test?
        sleep 1
        retry
      end
    end

    downloaded
  end
end
