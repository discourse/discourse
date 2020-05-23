# frozen_string_literal: true

module BackupRestore
  class BackupFileHandler
    OLD_DUMP_FILENAME = "dump.sql"

    delegate :log, to: :@logger, private: true

    def initialize(logger, filename, current_db, root_tmp_directory = Rails.root)
      @logger = logger
      @filename = filename
      @current_db = current_db
      @root_tmp_directory = root_tmp_directory
      @is_archive = !(@filename =~ /\.sql\.gz$/)
    end

    def decompress
      create_tmp_directory
      @archive_path = File.join(@tmp_directory, @filename)

      copy_archive_to_tmp_directory
      decompress_archive
      extract_db_dump

      [@tmp_directory, @db_dump_path]
    end

    def clean_up
      return if @tmp_directory.blank?

      log "Removing tmp '#{@tmp_directory}' directory..."
      FileUtils.rm_rf(@tmp_directory) if Dir[@tmp_directory].present?
    rescue => ex
      log "Something went wrong while removing the following tmp directory: #{@tmp_directory}", ex
    end

    protected

    def create_tmp_directory
      timestamp = Time.zone.now.strftime("%Y-%m-%d-%H%M%S")
      @tmp_directory = File.join(@root_tmp_directory, "tmp", "restores", @current_db, timestamp)
      ensure_directory_exists(@tmp_directory)
    end

    def ensure_directory_exists(directory)
      log "Making sure #{directory} exists..."
      FileUtils.mkdir_p(directory)
    end

    def copy_archive_to_tmp_directory
      store = BackupRestore::BackupStore.create

      if store.remote?
        log "Downloading archive to tmp directory..."
        failure_message = "Failed to download archive to tmp directory."
      else
        log "Copying archive to tmp directory..."
        failure_message = "Failed to copy archive to tmp directory."
      end

      store.download_file(@filename, @archive_path, failure_message)
    end

    def decompress_archive
      return if !@is_archive

      log "Unzipping archive, this may take a while..."
      pipeline = Compression::Pipeline.new([Compression::Tar.new, Compression::Gzip.new])
      unzipped_path = pipeline.decompress(@tmp_directory, @archive_path, available_size)
      pipeline.strip_directory(unzipped_path, @tmp_directory)
    end

    def extract_db_dump
      @db_dump_path =
        if @is_archive
          # for compatibility with backups from Discourse v1.5 and below
          old_dump_path = File.join(@tmp_directory, OLD_DUMP_FILENAME)
          File.exists?(old_dump_path) ? old_dump_path : File.join(@tmp_directory, BackupRestore::DUMP_FILE)
        else
          File.join(@tmp_directory, @filename)
        end

      if File.extname(@db_dump_path) == '.gz'
        log "Extracting dump file..."
        Compression::Gzip.new.decompress(@tmp_directory, @db_dump_path, available_size)
        @db_dump_path.delete_suffix!('.gz')
      end

      @db_dump_path
    end

    def available_size
      SiteSetting.decompressed_backup_max_file_size_mb
    end
  end
end
