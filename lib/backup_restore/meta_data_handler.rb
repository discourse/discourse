# frozen_string_literal: true

module BackupRestore
  MetaDataError = Class.new(RuntimeError)
  MigrationRequiredError = Class.new(RuntimeError)

  class MetaDataHandler
    METADATA_FILE = "meta.json"

    delegate :log, to: :@logger, private: true

    def initialize(logger, filename, tmp_directory)
      @logger = logger
      @current_database_version = BackupRestore.current_database_version
      @filename = filename
      @tmp_directory = tmp_directory
    end

    def validate
      metadata = extract_metadata

      if !metadata[:version].is_a?(Integer)
        raise MetaDataError.new("Version is not in a valid format.")
      end

      log "Validating metadata..."
      log "  Current database version: #{@current_database_version}"
      log "  Backup from database version: #{metadata[:version]}"
      log "  Current Discourse version: #{Discourse::VERSION::STRING}"
      log "  Backup from Discourse version: #{metadata[:discourse_version] || "(unknown)"}"

      if metadata[:discourse_version] &&
           Gem::Version.new(metadata[:discourse_version]) >
             Gem::Version.new(Discourse::VERSION::STRING)
        raise MigrationRequiredError.new(
                "This backup was created with Discourse #{metadata[:discourse_version]}, " \
                  "but this site is running Discourse #{Discourse::VERSION::STRING}. " \
                  "Upgrade this site before restoring the backup",
              )
      end

      if metadata[:version] > @current_database_version
        raise MigrationRequiredError.new(
                "This backup uses schema version #{metadata[:version]}, " \
                  "but this site is on schema version #{@current_database_version}. " \
                  "Upgrade this site before restoring the backup",
              )
      end

      metadata
    end

    protected

    # Tries to extract the backup version from an existing
    # metadata file (used in Discourse < v1.6) or from the filename.
    def extract_metadata
      metadata_path = File.join(@tmp_directory, METADATA_FILE) if @tmp_directory.present?

      if metadata_path.present? && File.exist?(metadata_path)
        metadata = load_metadata_file(metadata_path)
      else
        metadata = extract_filename_metadata
      end

      metadata
    end

    def extract_filename_metadata
      version_regexp = /\d{4}-\d{1,2}-\d+(?:-latest(?:-\d+)?)?/
      match =
        @filename.match(
          /-#{BackupRestore::VERSION_PREFIX}(?:(?<discourse_version>#{version_regexp})-)?(?<database_version>\d{14})/,
        )

      if !match
        raise MetaDataError.new("Version information is missing or invalid in the filename.")
      end

      metadata = { version: match[:database_version].to_i }
      discourse_version = match[:discourse_version]
      if discourse_version
        metadata[:discourse_version] = discourse_version.tr("-", ".").sub(".latest", "-latest")
      end
      metadata
    end

    def load_metadata_file(path)
      metadata = JSON.parse(File.read(path), symbolize_names: true)
      raise MetaDataError.new("Failed to load metadata file.") if metadata.blank?
      metadata
    rescue JSON::ParserError
      raise MetaDataError.new("Failed to parse metadata file.")
    end
  end
end
