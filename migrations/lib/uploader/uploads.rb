# frozen_string_literal: true

module Migrations::Uploader
  class Uploads
    attr_reader :settings, :databases

    def initialize(settings)
      @settings = settings
      run_uploads_db_migrations

      # TODO: Using "raw" db connection here
      #       Investigate using ::Migrations::Database::IntermediateDB.setup(db)
      #       Should we have a ::Migrations::Database::UploadsDB.setup(db)?
      @databases = {
        uploads_db: ::Migrations::Database.connect(@settings[:output_db_path]),
        intermediate_db: ::Migrations::Database.connect(@settings[:source_db_path]),
      }

      # disable logging for EXIFR which is used by ImageOptim
      EXIFR.logger = Logger.new(nil)
      SiteSettings.configure!(settings[:site_settings])
    end

    def perform!
      Tasks::Fixer.run!(databases, settings) if settings[:fix_missing]
      Tasks::Uploader.run!(databases, settings)
      Tasks::Optimizer.run!(databases, settings) if settings[:create_optimized_images]
    ensure
      databases[:uploads_db].close
      databases[:intermediate_db].close
    end

    def self.perform!(settings = {})
      new(settings).perform!
    end

    private

    def run_uploads_db_migrations
      ::Migrations::Database.migrate(
        settings[:output_db_path],
        migrations_path: ::Migrations::Database::UPLOADS_DB_SCHEMA_PATH,
      )
    end
  end
end
