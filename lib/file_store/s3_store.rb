require_dependency "file_store/base_store"
require_dependency "file_store/local_store"
require_dependency "s3_helper"
require_dependency "file_helper"

module FileStore

  class S3Store < BaseStore

    TOMBSTONE_PREFIX ||= "tombstone/"

    def initialize(s3_helper=nil)
      @s3_helper = s3_helper || S3Helper.new(s3_bucket, TOMBSTONE_PREFIX)
    end

    def store_upload(file, upload, content_type = nil)
      path = get_path_for_upload(upload)
      store_file(file, path, filename: upload.original_filename, content_type: content_type, cache_locally: true)
    end

    # options
    #   - filename
    #   - content_type
    #   - cache_locally
    def store_file(file, path, opts={})
      filename      = opts[:filename].presence
      content_type  = opts[:content_type].presence
      # cache file locally when needed
      cache_file(file, File.basename(path)) if opts[:cache_locally]
      # stored uploaded are public by default
      options = { acl: "public-read" }
      # add a "content disposition" header for "attachments"
      options[:content_disposition] = "attachment; filename=\"#{filename}\"" if filename && !FileHelper.is_image?(filename)
      # add a "content type" header when provided
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

    def has_been_uploaded?(url)
      return false if url.blank?
      return true if url.start_with?(absolute_base_url)
      return true if SiteSetting.s3_cdn_url.present? && url.start_with?(SiteSetting.s3_cdn_url)
      false
    end

    def absolute_base_url
      # cf. http://docs.aws.amazon.com/general/latest/gr/rande.html#s3_region
      @absolute_base_url ||= if SiteSetting.s3_region == "us-east-1"
        "//#{s3_bucket}.s3.amazonaws.com"
      else
        "//#{s3_bucket}.s3-#{SiteSetting.s3_region}.amazonaws.com"
      end
    end

    def external?
      true
    end

    def purge_tombstone(grace_period)
      @s3_helper.update_tombstone_lifecycle(grace_period)
    end

    def path_for(upload)
      url = upload.try(:url)
      FileStore::LocalStore.new.path_for(upload) if url && url[0] == "/" && url[1] != "/"
    end

    def cdn_url(url)
      return url if SiteSetting.s3_cdn_url.blank?
      url.sub(absolute_base_url, SiteSetting.s3_cdn_url)
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
      return @s3_bucket if @s3_bucket
      raise Discourse::SiteSettingMissing.new("s3_upload_bucket") if SiteSetting.s3_upload_bucket.blank?
      @s3_bucket = SiteSetting.s3_upload_bucket.downcase
    end

  end

end
