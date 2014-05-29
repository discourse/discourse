require 'file_store/base_store'
require_dependency "file_helper"

module FileStore

  class S3Store < BaseStore
    @fog_loaded ||= require 'fog'

    def store_upload(file, upload, content_type = nil)
      path = get_path_for_upload(file, upload)
      store_file(file, path, upload.original_filename, content_type)
    end

    def store_optimized_image(file, optimized_image)
      path = get_path_for_optimized_image(file, optimized_image)
      store_file(file, path)
    end

    def store_avatar(file, avatar, size)
      path = get_path_for_avatar(file, avatar, size)
      store_file(file, path)
    end

    def remove_upload(upload)
      remove_file(upload.url)
    end

    def remove_optimized_image(optimized_image)
      remove_file(optimized_image.url)
    end

    def has_been_uploaded?(url)
      url.start_with?(absolute_base_url)
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
      url = SiteSetting.scheme + ":" + upload.url
      max_file_size = [SiteSetting.max_image_size_kb, SiteSetting.max_attachment_size_kb].max.kilobytes

      FileHelper.download(url, max_file_size, "discourse-s3")
    end

    def avatar_template(avatar)
      template = relative_avatar_template(avatar)
      "#{absolute_base_url}/#{template}"
    end

    def purge_tombstone(grace_period)
      update_tombstone_lifecycle(grace_period)
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

    def store_file(file, path, filename = nil, content_type = nil)
      # if this fails, it will throw an exception
      upload(file, path, filename, content_type)
      # url
      "#{absolute_base_url}/#{path}"
    end

    def remove_file(url)
      return unless has_been_uploaded?(url)
      filename = File.basename(url)
      remove(filename)
    end

    def s3_bucket
      SiteSetting.s3_upload_bucket.downcase
    end

    def check_missing_site_settings
      raise Discourse::SiteSettingMissing.new("s3_upload_bucket")     if SiteSetting.s3_upload_bucket.blank?
      raise Discourse::SiteSettingMissing.new("s3_access_key_id")     if SiteSetting.s3_access_key_id.blank?
      raise Discourse::SiteSettingMissing.new("s3_secret_access_key") if SiteSetting.s3_secret_access_key.blank?
    end

    def s3_options
      options = {
        provider: 'AWS',
        aws_access_key_id: SiteSetting.s3_access_key_id,
        aws_secret_access_key: SiteSetting.s3_secret_access_key,
        scheme: SiteSetting.scheme,
        # cf. https://github.com/fog/fog/issues/2381
        path_style: dns_compatible?(s3_bucket, SiteSetting.use_https?),
      }
      options[:region] = SiteSetting.s3_region unless SiteSetting.s3_region.empty?
      options
    end

    def fog_with_options
      check_missing_site_settings
      Fog::Storage.new(s3_options)
    end

    def get_or_create_directory(bucket)
      fog = fog_with_options
      directory = fog.directories.get(bucket)
      directory = fog.directories.create(key: bucket) unless directory
      directory
    end

    def upload(file, unique_filename, filename=nil, content_type=nil)
      args = {
        key: unique_filename,
        public: true,
        body: file
      }
      args[:content_disposition] = "attachment; filename=\"#{filename}\"" if filename
      args[:content_type] = content_type if content_type

      get_or_create_directory(s3_bucket).files.create(args)
    end

    def remove(unique_filename)
      fog = fog_with_options
      # copy the file in tombstone
      fog.copy_object(unique_filename, s3_bucket, tombstone_prefix + unique_filename, s3_bucket)
      # delete the file
      fog.delete_object(s3_bucket, unique_filename)
    rescue Excon::Errors::NotFound
      # If the file cannot be found, don't raise an error.
      # I am not certain if this is the right thing to do but we can't deploy
      # right now. Please review this @ZogStriP
    end

    def update_tombstone_lifecycle(grace_period)
      # cf. http://docs.aws.amazon.com/AmazonS3/latest/dev/object-lifecycle-mgmt.html
      fog_with_options.put_bucket_lifecycle(s3_bucket, lifecycle(grace_period))
    end

    def lifecycle(grace_period)
      {
        "Rules" => [{
          "Prefix" => tombstone_prefix,
          "Enabled" => true,
          "Expiration" => { "Days" => grace_period }
        }]
      }
    end

    def tombstone_prefix
      "tombstone/"
    end

    # cf. https://github.com/aws/aws-sdk-core-ruby/blob/master/lib/aws/plugins/s3_bucket_dns.rb#L56-L78
    def dns_compatible?(bucket_name, ssl)
      if valid_subdomain?(bucket_name)
        bucket_name.match(/\./) && ssl ? false : true
      else
        false
      end
    end

    def valid_subdomain?(bucket_name)
      bucket_name.size < 64 &&
      bucket_name =~ /^[a-z0-9][a-z0-9.-]+[a-z0-9]$/ &&
      bucket_name !~ /(\d+\.){3}\d+/ &&
      bucket_name !~ /[.-]{2}/
    end

  end

end
