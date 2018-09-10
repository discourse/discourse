require_dependency "backup_restore/backup_store"
require_dependency "disk_space"

module BackupRestore
  class LocalBackupStore < BackupStore
    def self.base_directory(current_db = nil)
      current_db ||= RailsMultisite::ConnectionManagement.current_db
      base_directory = File.join(Rails.root, "public", "backups", current_db)
      FileUtils.mkdir_p(base_directory) unless Dir.exists?(base_directory)
      base_directory
    end

    def self.chunk_path(identifier, filename, chunk_number)
      File.join(LocalBackupStore.base_directory, "tmp", identifier, "#{filename}.part#{chunk_number}")
    end

    def remote?
      false
    end

    def file(filename, include_download_source: false)
      path = path_from_filename(filename)
      create_file_from_path(path, include_download_source) if File.exists?(path)
    end

    def delete_file(filename)
      path = path_from_filename(filename)
      FileUtils.remove_file(path, force: true) if File.exists?(path)
      DiskSpace.reset_cached_stats
    end

    def download_file(filename, destination, failure_message = "")
      path = path_from_filename(filename)
      Discourse::Utils.execute_command('cp', path, destination, failure_message: failure_message)
    end

    protected

    def unsorted_files
      Dir.glob(File.join(LocalBackupStore.base_directory, "*.{gz,tgz}"))
        .map { |filename| create_file_from_path(filename) }
    end

    private

    def path_from_filename(filename)
      File.join(LocalBackupStore.base_directory, filename)
    end

    def create_file_from_path(path, include_download_source = false)
      BackupFile.new(
        filename: File.basename(path),
        size: File.size(path),
        last_modified: File.mtime(path).utc,
        source: include_download_source ? path : nil
      )
    end
  end
end
