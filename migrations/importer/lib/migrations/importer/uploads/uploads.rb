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
          tasks = build_tasks
          reporter = Reporting::Factory.build(titles: tasks.map(&:title))

          interrupted = false
          begin
            tasks.each do |task|
              pipeline = Pipeline.new(task:, reporter:)
              pipeline.run
              interrupted = pipeline.interrupted?
              break if interrupted
            end
          ensure
            reporter.close
          end

          # The reporter is closed and the terminal restored, so this lands
          # cleanly below its output. The tasks resume from what already reached
          # disk (they skip ids already recorded), so re-running continues.
          puts "", I18n.t("importer.uploads.interrupted") if interrupted
        ensure
          cleanup_resources
        end

        def self.perform!(settings = {})
          new(settings).perform!
        end

        private

        def build_tasks
          [].tap do |tasks|
            tasks << Tasks::Fixer.new(databases, settings) if settings[:fix_missing]
            tasks << Tasks::Uploader.new(databases, settings)
            tasks << Tasks::Optimizer.new(databases, settings) if settings[:create_optimized_images]
          end
        end

        def setup_databases
          run_files_db_migrations

          files_db = Database.connect(settings[:output_db_path])
          # The generated `FilesDB::*` models insert through this module-level
          # connection; the tasks use the same object directly for their reads and
          # deletes.
          Database::FilesDB.setup(files_db)

          { files_db:, intermediate_db: Database.connect(settings[:source_db_path]) }
        end

        def run_files_db_migrations
          Database.migrate(
            settings[:output_db_path],
            migrations_path: Database::FILES_DB_SCHEMA_PATH,
          )
        end

        def configure_services
          configure_logging
          configure_site_settings
        end

        def configure_logging
          @original_exifr_logger = EXIFR.logger

          # disable logging for EXIFR which is used by ImageOptim
          EXIFR.logger = Logger.new(nil)
        end

        def configure_site_settings
          SiteSettings.configure!(settings[:site_settings])
        end

        def cleanup_resources
          databases.values.each(&:close)
          EXIFR.logger = @original_exifr_logger
        end
      end
    end
  end
end
