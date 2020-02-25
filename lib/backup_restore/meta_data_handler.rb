# frozen_string_literal: true

module BackupRestore
  MetaDataError = Class.new(RuntimeError)
  MigrationRequiredError = Class.new(RuntimeError)

  class MetaDataHandler
    METADATA_FILE = "meta.json"

    delegate :log, to: :@logger, private: true

    def initialize(logger, filename, tmp_directory)
      @logger = logger
      @current_version = BackupRestore.current_version
      @filename = filename
      @tmp_directory = tmp_directory
    end

    def validate
      metadata = extract_metadata

      if !metadata[:version].is_a?(Integer)
        raise MetaDataError.new("Version is not in a valid format.")
      end

      log "Validating metadata..."
      log "  Current version: #{@current_version}"
      log "  Restored version: #{metadata[:version]}"

      if metadata[:version] > @current_version
        raise MigrationRequiredError.new("You're trying to restore a more recent version of the schema. " \
          "You should migrate first!")
      end

      metadata
    end

    protected

    # Tries to extract the backup version from an existing
    # metadata file (used in Discourse < v1.6) or from the filename.
    def extract_metadata
      metadata_path = File.join(@tmp_directory, METADATA_FILE) if @tmp_directory.present?

      if metadata_path.present? && File.exists?(metadata_path)
        metadata = load_metadata_file(metadata_path)
      elsif @filename =~ /-#{BackupRestore::VERSION_PREFIX}(\d{14})/
        metadata = { version: Regexp.last_match[1].to_i }
      else
        raise MetaDataError.new("Migration version is missing from the filename.")
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
