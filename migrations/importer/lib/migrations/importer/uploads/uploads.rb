# frozen_string_literal: true

module Migrations
  module Importer
    module Uploads
      class Uploads
        attr_reader :settings, :databases

        def initialize(settings)
          @settings = settings
          @databases = setup_databases
          configure_services
        end

        def perform!
          tasks = build_task_pipeline
          tasks.each { |task| task.run!(databases, settings) }
        ensure
          cleanup_resources
        end

        def self.perform!(settings = {})
          new(settings).perform!
        end

        private

        def build_task_pipeline
          [].tap do |tasks|
            tasks << Tasks::Fixer if settings[:fix_missing]
            tasks << Tasks::Uploader
            tasks << Tasks::Optimizer if settings[:create_optimized_images]
          end
        end

        def setup_databases
          run_uploads_db_migrations

          {
            uploads_db: create_database_connection(:uploads),
            intermediate_db: create_database_connection(:intermediate),
          }
        end

        def create_database_connection(type)
          path = type == :uploads ? settings[:output_db_path] : settings[:source_db_path]

          # TODO: Using "raw" db connection here for now
          #       Investigate using Migrations::Database::IntermediateDB.setup(db)
          #       Should we have a Migrations::Database::UploadsDB.setup(db)?
          Database.connect(path)
        end

        def run_uploads_db_migrations
          Database.migrate(
            settings[:output_db_path],
            migrations_path: Database::UPLOADS_DB_SCHEMA_PATH,
          )
        end

        def configure_services
          configure_site_settings
        end

        def configure_site_settings
          SiteSettings.configure!(settings[:site_settings])
        end

        def cleanup_resources
          databases.values.each(&:close)
        end
      end
    end
  end
end
