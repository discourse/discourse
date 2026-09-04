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

          files_db = Database.connect(settings[:files_db])
          # The generated `FilesDB::*` models insert through this module-level
          # connection; the tasks use the same object directly for their reads and
          # deletes.
          Database::FilesDB.setup(files_db)

          { files_db:, intermediate_db: Database.connect(settings[:intermediate_db]) }
        end

        def run_files_db_migrations
          Database.migrate(settings[:files_db], migrations_path: Database::FILES_DB_SCHEMA_PATH)
        end

        # Cap a single ImageMagick convert so it can't be the one process that
        # balloons past a memory tick and OOMs the box between the controller's
        # samples. This is a per-process backstop under the adaptive controller's
        # box-wide memory watch.
        MAGICK_MEMORY_CAP = 2 * 1024**3 # 2 GB

        def configure_services
          # Resize the pool first. Anything below that re-establishes the AR
          # connection captures the pool size as it stands at that moment (it
          # deep-dups the current config), so a resize afterwards would be
          # thrown away. Keep this ahead of the rest of the service setup.
          adjust_db_pool_size
          configure_logging
          configure_image_memory_limits
          configure_site_settings
          DiscoursePatches.apply!
        end

        # The worker pool opens one Discourse DB connection per thread, so the AR
        # pool has to be wide enough to hand them all out. Grow it up to the
        # server's `max_connections`; leave it alone if it is already that big.
        def adjust_db_pool_size
          max_db_connections = ::DB.query_single("SHOW max_connections").first.to_i
          current_size = ActiveRecord::Base.connection_pool.size
          return if current_size >= max_db_connections

          db_config = ActiveRecord::Base.connection_db_config.configuration_hash.dup
          db_config[:pool] = max_db_connections
          ActiveRecord::Base.establish_connection(db_config)
        end

        def configure_logging
          @original_exifr_logger = EXIFR.logger

          # disable logging for EXIFR which is used by ImageOptim
          EXIFR.logger = Logger.new(nil)
        end

        # A convert's peak memory is also bounded by `max_image_megapixels` (set in
        # {SiteSettings}), which caps how large an image we'll decode in the first
        # place. This adds a hard resource ceiling on top of that.
        #
        # An explicit `MAGICK_MEMORY_LIMIT` in the environment wins — the operator
        # asked for it. So does a stricter `policy.xml`: the environment can only
        # *lower* ImageMagick's limits, never raise them past what policy allows.
        def configure_image_memory_limits
          return if ENV["MAGICK_MEMORY_LIMIT"]

          total = ResourceSampler.new(usable_cpus: 1).total_memory_bytes
          bound = total ? [MAGICK_MEMORY_CAP, total / 8].min : MAGICK_MEMORY_CAP

          ENV["MAGICK_MEMORY_LIMIT"] = bound.to_s
          ENV["MAGICK_MAP_LIMIT"] ||= (bound * 2).to_s

          puts I18n.t("importer.uploads.image_memory_limit", mib: bound / 1024 / 1024)
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
