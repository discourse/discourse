# frozen_string_literal: true

module BackupRestore
  class S3BackupStore < BackupStore
    UPLOAD_URL_EXPIRES_AFTER_SECONDS ||= 21_600 # 6 hours
    MULTISITE_PREFIX = "backups"

    def initialize(opts = {})
      s3_options = S3Helper.s3_options(SiteSetting)
      s3_options.merge!(opts[:s3_options]) if opts[:s3_options]
      @s3_helper = S3Helper.new(s3_bucket_name_with_prefix, '', s3_options)
    end

    def remote?
      true
    end

    def file(filename, include_download_source: false)
      obj = @s3_helper.object(filename)
      create_file_from_object(obj, include_download_source) if obj.exists?
    end

    def delete_file(filename)
      obj = @s3_helper.object(filename)

      if obj.exists?
        obj.delete
        reset_cache
      end
    end

    def download_file(filename, destination_path, failure_message = nil)
      @s3_helper.download_file(filename, destination_path, failure_message)
    end

    def upload_file(filename, source_path, content_type)
      obj = @s3_helper.object(filename)
      raise BackupFileExists.new if obj.exists?

      obj.upload_file(source_path, content_type: content_type)
      reset_cache
    end

    def generate_upload_url(filename)
      obj = @s3_helper.object(filename)
      raise BackupFileExists.new if obj.exists?

      ensure_cors!
      presigned_url(obj, :put, UPLOAD_URL_EXPIRES_AFTER_SECONDS)
    rescue Aws::Errors::ServiceError => e
      Rails.logger.warn("Failed to generate upload URL for S3: #{e.message.presence || e.class.name}")
      raise StorageError
    end

    private

    def unsorted_files
      objects = []

      @s3_helper.list.each do |obj|
        if obj.key.match?(file_regex)
          objects << create_file_from_object(obj)
        end
      end

      objects
    rescue Aws::Errors::ServiceError => e
      Rails.logger.warn("Failed to list backups from S3: #{e.message.presence || e.class.name}")
      raise StorageError
    end

    def create_file_from_object(obj, include_download_source = false)
      expires = S3Helper::DOWNLOAD_URL_EXPIRES_AFTER_SECONDS
      BackupFile.new(
        filename: File.basename(obj.key),
        size: obj.size,
        last_modified: obj.last_modified,
        source: include_download_source ? presigned_url(obj, :get, expires) : nil
      )
    end

    def presigned_url(obj, method, expires_in_seconds)
      obj.presigned_url(method, expires_in: expires_in_seconds)
    end

    def ensure_cors!
      rule = {
        allowed_headers: ["*"],
        allowed_methods: ["PUT"],
        allowed_origins: [Discourse.base_url_no_prefix],
        max_age_seconds: 3000
      }

      @s3_helper.ensure_cors!([rule])
    end

    def cleanup_allowed?
      !SiteSetting.s3_disable_cleanup
    end

    def s3_bucket_name_with_prefix
      if Rails.configuration.multisite
        File.join(SiteSetting.s3_backup_bucket, MULTISITE_PREFIX, RailsMultisite::ConnectionManagement.current_db)
      else
        SiteSetting.s3_backup_bucket
      end
    end

    def file_regex
      @file_regex ||= begin
        path = @s3_helper.s3_bucket_folder_path || ""

        if path.present?
          path = "#{path}/" unless path.end_with?("/")
          path = Regexp.quote(path)
        end

        /^#{path}[^\/]*\.t?gz$/i
      end
    end

    def free_bytes
      nil
    end
  end
end
