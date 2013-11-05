require 'file_store/base_store'

module FileStore

  class S3Store < BaseStore
    @fog_loaded ||= require 'fog'

    def store_upload(file, upload)
      path = get_path_for_upload(file, upload)
      store_file(file, path, upload.original_filename, file.content_type)
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
      @open_uri_loaded ||= require 'open-uri'

      extension = File.extname(upload.original_filename)
      temp_file = Tempfile.new(["discourse-s3", extension])
      url = (SiteSetting.use_ssl? ? "https:" : "http:") + upload.url

      File.open(temp_file.path, "wb") do |f|
        f.write(open(url, "rb", read_timeout: 5).read)
      end

      temp_file
    end

    def absolute_avatar_template(avatar)
      "#{absolute_base_url}/avatars/#{avatar.sha1}/{size}#{avatar.extension}"
    end

    private

    def get_path_for_upload(file, upload)
      "#{upload.id}#{upload.sha1}#{upload.extension}"
    end

    def get_path_for_optimized_image(file, optimized_image)
      "#{optimized_image.id}#{optimized_image.sha1}_#{optimized_image.width}x#{optimized_image.height}#{optimized_image.extension}"
    end

    def get_path_for_avatar(file, avatar, size)
      "avatars/#{avatar.sha1}/#{size}#{avatar.extension}"
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

    def get_or_create_directory(bucket)
      check_missing_site_settings

      fog = Fog::Storage.new(s3_options)

      directory = fog.directories.get(bucket)
      directory = fog.directories.create(key: bucket) unless directory
      directory
    end

    def s3_options
      options = {
        provider: 'AWS',
        aws_access_key_id: SiteSetting.s3_access_key_id,
        aws_secret_access_key: SiteSetting.s3_secret_access_key,
      }
      options[:region] = SiteSetting.s3_region unless SiteSetting.s3_region.empty?
      options
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
      check_missing_site_settings

      fog = Fog::Storage.new(s3_options)

      fog.delete_object(s3_bucket, unique_filename)
    end

  end

end
