# frozen_string_literal: true

module BackupRestore
  class LocalBackupStore < BackupStore
    def self.base_directory(db: nil, root_directory: nil)
      current_db = db || RailsMultisite::ConnectionManagement.current_db
      root_directory ||= File.join(Rails.root, "public", "backups")

      base_directory = File.join(root_directory, current_db)
      FileUtils.mkdir_p(base_directory) unless Dir.exists?(base_directory)
      base_directory
    end

    def self.chunk_path(identifier, filename, chunk_number)
      File.join(LocalBackupStore.base_directory, "tmp", identifier, "#{filename}.part#{chunk_number}")
    end

    def initialize(opts = {})
      @base_directory = LocalBackupStore.base_directory(root_directory: opts[:root_directory])
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

      if File.exists?(path)
        File.delete(path)
        reset_cache
      end
    end

    def download_file(filename, destination, failure_message = "")
      path = path_from_filename(filename)
      Discourse::Utils.execute_command('cp', path, destination, failure_message: failure_message)
    end

    private

    def unsorted_files
      files = Dir.glob(File.join(@base_directory, "*.{gz,tgz}"))
      files.map! { |filename| create_file_from_path(filename) }
      files
    end

    def path_from_filename(filename)
      File.join(@base_directory, filename)
    end

    def create_file_from_path(path, include_download_source = false)
      BackupFile.new(
        filename: File.basename(path),
        size: File.size(path),
        last_modified: File.mtime(path).utc,
        source: include_download_source ? path : nil
      )
    end

    def free_bytes
      DiskSpace.free(@base_directory)
    end
  end
end
