# frozen_string_literal: true

require "file_store/object_storage/s3"

module BackupRestore
  class S3BackupStore < BackupStore
    UPLOAD_URL_EXPIRES_AFTER_SECONDS = 6.hours.to_i

    # Legacy callers may depend on SDK response objects. Core uses object_storage.
    delegate :abort_multipart,
             :presign_multipart_part,
             :list_multipart_parts,
             :complete_multipart,
             to: :s3_helper

    def initialize(opts = {})
      @object_storage = opts[:object_storage]
      @s3_options = S3Helper.s3_options(SiteSetting)
      @s3_options.merge!(opts[:s3_options]) if opts[:s3_options]
    end

    def s3_helper
      @s3_helper ||= S3Helper.new(s3_bucket_name_with_prefix, "", @s3_options.clone)
    end

    def object_storage
      @object_storage ||= FileStore::ObjectStorage::S3.new(s3_helper)
    end

    def remote?
      true
    end

    def file(filename, include_download_source: false)
      obj = object_storage.stat(filename)
      create_file_from_object(obj, include_download_source) if obj
    rescue FileStore::ObjectStorage::Error => error
      FileStore::ObjectStorage::S3.raise_legacy(error)
    end

    def delete_file(filename)
      if object_storage.stat(filename)
        object_storage.delete(filename)
        reset_cache
      end
    rescue FileStore::ObjectStorage::Error => error
      FileStore::ObjectStorage::S3.raise_legacy(error)
    end

    def download_file(filename, destination_path, failure_message = nil)
      object_storage.download(filename, destination_path, failure_message:)
    rescue FileStore::ObjectStorage::Error => error
      # Preserve the legacy store API while the adapter exposes typed failures.
      raise error.message
    rescue => error
      raise failure_message&.to_s ||
              "Failed to download #{filename} because #{error.message.presence || error.class}"
    end

    def upload_file(filename, source_path, content_type)
      raise BackupFileExists.new if object_storage.stat(filename)

      object_storage.upload_file(
        filename,
        source_path,
        visibility: :bucket_default,
        headers: {
          content_type:,
        },
      )
      reset_cache
    rescue FileStore::ObjectStorage::Error => error
      FileStore::ObjectStorage::S3.raise_legacy(error)
    end

    def generate_upload_url(filename)
      raise BackupFileExists.new if object_storage.stat(filename)

      s3_helper.ensure_cors!([S3CorsRulesets::BACKUP_DIRECT_UPLOAD])

      object_storage.upload_url(filename, expires_in: UPLOAD_URL_EXPIRES_AFTER_SECONDS)
    rescue FileStore::ObjectStorage::Error, Aws::Errors::ServiceError => e
      raise_backup_storage_error(e, "Failed to generate upload URL for S3")
    end

    def temporary_upload_path(file_name)
      FileStore::BaseStore.temporary_upload_path(file_name, folder_prefix: temporary_folder_prefix)
    end

    def temporary_folder_prefix
      folder_prefix = s3_helper.s3_bucket_folder_path.nil? ? "" : s3_helper.s3_bucket_folder_path

      if Rails.env.test?
        folder_prefix = File.join(folder_prefix, "test_#{Discourse.test_env_number}")
      end

      folder_prefix
    end

    def create_multipart(file_name, content_type, metadata: {})
      prepare_multipart_upload(file_name, content_type, metadata:)
    rescue FileStore::ObjectStorage::Error => error
      FileStore::ObjectStorage::S3.raise_legacy(error)
    end

    def prepare_multipart_upload(file_name, content_type, metadata: {})
      raise BackupFileExists.new if object_storage.stat(file_name)
      key = temporary_upload_path(file_name)

      object_storage.create_multipart(key, content_type, metadata: metadata, visibility: :private)
    end

    def move_existing_stored_upload(
      existing_external_upload_key:,
      original_filename: nil,
      content_type: nil
    )
      object_storage.copy(
        existing_external_upload_key,
        File.join(s3_helper.s3_bucket_folder_path, original_filename),
        visibility: :private,
        replace_metadata: true,
      )

      object_storage.delete(existing_external_upload_key, exact: true)
    rescue FileStore::ObjectStorage::Error => error
      FileStore::ObjectStorage::S3.raise_legacy(error)
    end

    def object_from_path(path)
      s3_helper.object(path)
    end

    private

    def raise_backup_storage_error(error, message)
      original = FileStore::ObjectStorage::S3.legacy_error(error)
      # The legacy wrapper caught service errors, not transport or credential failures.
      if FileStore::ObjectStorage::S3.sdk_error?(original) &&
           !original.is_a?(Aws::Errors::ServiceError)
        raise original, cause: original.cause
      end
      detail = original.message.presence || original.class.name
      Rails.logger.warn("#{message}: #{detail}")
      raise StorageError.new(detail), cause: original
    end

    def unsorted_files
      objects = []

      object_storage.list.each do |obj|
        objects << create_file_from_object(obj) if obj.key.match?(file_regex)
      end

      objects
    rescue FileStore::ObjectStorage::Error => e
      raise_backup_storage_error(e, "Failed to list backups from S3")
    end

    def create_file_from_object(obj, include_download_source = false)
      expires = SiteSetting.s3_presigned_get_url_expires_after_seconds
      BackupFile.new(
        filename: File.basename(obj.key),
        size: obj.size,
        last_modified: obj.last_modified,
        source:
          include_download_source ? object_storage.download_url(obj.key, expires_in: expires) : nil,
      )
    end

    def cleanup_allowed?
      !SiteSetting.s3_disable_cleanup
    end

    def s3_bucket_name_with_prefix
      File.join(SiteSetting.s3_backup_bucket, RailsMultisite::ConnectionManagement.current_db)
    end

    def file_regex
      @file_regex ||=
        begin
          path = s3_helper.s3_bucket_folder_path || ""

          if path.present?
            path = "#{path}/" unless path.end_with?("/")
            path = Regexp.quote(path)
          end

          %r{\A#{path}[^/]*\.t?gz\z}i
        end
    end

    def free_bytes
      nil
    end
  end
end
