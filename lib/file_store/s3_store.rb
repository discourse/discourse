require 'file_store/base_store'
require_dependency "s3_helper"
require_dependency "file_helper"

module FileStore

  class S3Store < BaseStore

    def initialize(s3_helper = nil)
      @s3_helper = s3_helper || S3Helper.new(s3_bucket, tombstone_prefix)
    end

    def store_upload(file, upload, content_type = nil)
      path = get_path_for_upload(file, upload)
      store_file(file, path, upload.original_filename, content_type)
    end

    def store_optimized_image(file, optimized_image)
      path = get_path_for_optimized_image(file, optimized_image)
      store_file(file, path)
    end

    def remove_upload(upload)
      remove_file(upload.url)
    end

    def remove_optimized_image(optimized_image)
      remove_file(optimized_image.url)
    end

    def has_been_uploaded?(url)
      url.present? && url.start_with?(absolute_base_url)
    end

    def absolute_base_url
      "//#{s3_bucket}.s3.amazonaws.com"
    end

    def external?
      true
    end

    def internal?
      !external?
    end

    def download(upload)
      return unless has_been_uploaded?(upload.url)
      url = SiteSetting.scheme + ":" + upload.url
      max_file_size = [SiteSetting.max_image_size_kb, SiteSetting.max_attachment_size_kb].max.kilobytes
      FileHelper.download(url, max_file_size, "discourse-s3", true)
    end

    def avatar_template(avatar)
      template = relative_avatar_template(avatar)
      "#{absolute_base_url}/#{template}"
    end

    def purge_tombstone(grace_period)
      @s3_helper.update_tombstone_lifecycle(grace_period)
    end

    private

      def get_path_for_upload(file, upload)
        "#{upload.id}#{upload.sha1}#{upload.extension}"
      end

      def get_path_for_optimized_image(file, optimized_image)
        "#{optimized_image.id}#{optimized_image.sha1}_#{optimized_image.width}x#{optimized_image.height}#{optimized_image.extension}"
      end

      def get_path_for_avatar(file, avatar, size)
        relative_avatar_template(avatar).gsub("{size}", size.to_s)
      end

      def relative_avatar_template(avatar)
        "avatars/#{avatar.sha1}/{size}#{avatar.extension}"
      end

      def store_file(file, path, filename=nil, content_type=nil)
        # stored uploaded are public by default
        options = { public: true }
        # add a "content disposition" header for "attachments"
        options[:content_disposition] = "attachment; filename=\"#{filename}\"" if filename && !FileHelper.is_image?(filename)
        # add a "content type" header when provided (ie. for "attachments")
        options[:content_type] = content_type if content_type
        # if this fails, it will throw an exception
        @s3_helper.upload(file, path, options)
        # return the upload url
        "#{absolute_base_url}/#{path}"
      end

      def remove_file(url)
        return unless has_been_uploaded?(url)
        filename = File.basename(url)
        # copy the removed file to tombstone
        @s3_helper.remove(filename, true)
      end

      def s3_bucket
        return @s3_bucket if @s3_bucket
        raise Discourse::SiteSettingMissing.new("s3_upload_bucket") if SiteSetting.s3_upload_bucket.blank?
        @s3_bucket = SiteSetting.s3_upload_bucket.downcase
      end

      def tombstone_prefix
        "tombstone/"
      end

  end

end
