require "uri"
require "mini_mime"
require_dependency "file_store/base_store"
require_dependency "s3_helper"
require_dependency "file_helper"

module FileStore

  class S3Store < BaseStore
    TOMBSTONE_PREFIX ||= "tombstone/"

    def initialize(s3_helper = nil)
      @s3_helper = s3_helper || S3Helper.new(s3_bucket, TOMBSTONE_PREFIX)
    end

    def store_upload(file, upload, content_type = nil)
      path = get_path_for_upload(upload)
      store_file(file, path, filename: upload.original_filename, content_type: content_type, cache_locally: true)
    end

    def store_optimized_image(file, optimized_image, content_type = nil)
      path = get_path_for_optimized_image(optimized_image)
      store_file(file, path, content_type: content_type)
    end

    # options
    #   - filename
    #   - content_type
    #   - cache_locally
    def store_file(file, path, opts = {})
      filename = opts[:filename].presence || File.basename(path)
      # cache file locally when needed
      cache_file(file, File.basename(path)) if opts[:cache_locally]
      # stored uploaded are public by default
      options = {
        acl: "public-read",
        content_type: opts[:content_type].presence || MiniMime.lookup_by_filename(filename)&.content_type
      }
      # add a "content disposition" header for "attachments"
      options[:content_disposition] = "attachment; filename=\"#{filename}\"" unless FileHelper.is_image?(filename)
      # if this fails, it will throw an exception
      path = @s3_helper.upload(file, path, options)
      # return the upload url
      "#{absolute_base_url}/#{path}"
    end

    def remove_file(url, path)
      return unless has_been_uploaded?(url)
      # copy the removed file to tombstone
      @s3_helper.remove(path, true)
    end

    def has_been_uploaded?(url)
      return false if url.blank?

      base_hostname = URI.parse(absolute_base_url).hostname
      return true if url[base_hostname]

      return false if SiteSetting.Upload.s3_cdn_url.blank?
      cdn_hostname = URI.parse(SiteSetting.Upload.s3_cdn_url || "").hostname
      cdn_hostname.presence && url[cdn_hostname]
    end

    def s3_bucket_name
      @s3_helper.s3_bucket_name
    end

    def absolute_base_url
      @absolute_base_url ||= SiteSetting.Upload.absolute_base_url
    end

    def external?
      true
    end

    def purge_tombstone(grace_period)
      @s3_helper.update_tombstone_lifecycle(grace_period)
    end

    def path_for(upload)
      url = upload.try(:url)
      FileStore::LocalStore.new.path_for(upload) if url && url[/^\/[^\/]/]
    end

    def cdn_url(url)
      return url if SiteSetting.Upload.s3_cdn_url.blank?
      schema = url[/^(https?:)?\/\//, 1]
      folder = @s3_helper.s3_bucket_folder_path.nil? ? "" : "#{@s3_helper.s3_bucket_folder_path}/"
      url.sub("#{schema}#{absolute_base_url}/#{folder}", "#{SiteSetting.Upload.s3_cdn_url}/")
    end

    def cache_avatar(avatar, user_id)
      source = avatar.url.sub(absolute_base_url + "/", "")
      destination = avatar_template(avatar, user_id).sub(absolute_base_url + "/", "")
      @s3_helper.copy(source, destination)
    end

    def avatar_template(avatar, user_id)
      UserAvatar.external_avatar_url(user_id, avatar.upload_id, avatar.width)
    end

    def s3_bucket
      raise Discourse::SiteSettingMissing.new("s3_upload_bucket") if SiteSetting.Upload.s3_upload_bucket.blank?
      SiteSetting.Upload.s3_upload_bucket.downcase
    end
  end
end
