module BackupRestore
  # @abstract
  class BackupStore
    class BackupFileExists < RuntimeError; end
    class StorageError < RuntimeError; end

    # @return [BackupStore]
    def self.create(opts = {})
      case SiteSetting.backup_location
      when BackupLocationSiteSetting::LOCAL
        require_dependency "backup_restore/local_backup_store"
        BackupRestore::LocalBackupStore.new(opts)
      when BackupLocationSiteSetting::S3
        require_dependency "backup_restore/s3_backup_store"
        BackupRestore::S3BackupStore.new(opts)
      end
    end

    # @return [Array<BackupFile>]
    def files
      unsorted_files.sort_by { |file| -file.last_modified.to_i }
    end

    # @return [BackupFile]
    def latest_file
      files.first
    end

    def delete_old
      return unless cleanup_allowed?
      return if (backup_files = files).size <= SiteSetting.maximum_backups

      backup_files[SiteSetting.maximum_backups..-1].each do |file|
        delete_file(file.filename)
      end
    end

    def remote?
      fail NotImplementedError
    end

    # @return [BackupFile]
    def file(filename, include_download_source: false)
      fail NotImplementedError
    end

    def delete_file(filename)
      fail NotImplementedError
    end

    def download_file(filename, destination, failure_message = nil)
      fail NotImplementedError
    end

    def upload_file(filename, source_path, content_type)
      fail NotImplementedError
    end

    def generate_upload_url(filename)
      fail NotImplementedError
    end

    private

    # @return [Array<BackupFile>]
    def unsorted_files
      fail NotImplementedError
    end

    def cleanup_allowed?
      true
    end
  end
end
