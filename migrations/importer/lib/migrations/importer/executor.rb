# frozen_string_literal: true

module Migrations
  module Importer
    class Executor
      def initialize(config, options)
        @intermediate_db = Database.connect(config[:intermediate_db])
        @discourse_db = DiscourseDB.new
        @shared_data = SharedData.new(@discourse_db)
        @config = config[:config]
        @options = options

        attach_mappings_db(config[:mappings_db], options[:reset])
        attach_files_db(config[:files_db])
      end

      def start
        runtime =
          DateHelper.track_time do
            optimize_intermediate_db
            execute_steps
          ensure
            cleanup
          end

        puts I18n.t("importer.done", runtime: DateHelper.human_readable_time(runtime))
      rescue SignalException
        @aborted = true
        exit(130)
      ensure
        # `cleanup` (above) has already closed the reporter and restored the
        # terminal, so this abort line lands cleanly below the reporter output.
        STDERR.puts "\n#{I18n.t("cli.aborted")}" if @aborted
      end

      private

      def attach_mappings_db(db_path, reset)
        Database.delete_database(db_path) if reset
        migrate_and_attach(db_path, Database::MAPPINGS_DB_SCHEMA_PATH, "mapped")
      end

      def attach_files_db(db_path)
        # An import can run without a files database (no uploads). The steps that
        # read from it check whether it is attached and skip when it is not.
        return if db_path.blank?

        migrate_and_attach(db_path, Database::FILES_DB_SCHEMA_PATH, "files")
      end

      def migrate_and_attach(db_path, schema_path, alias_name)
        Database.migrate(db_path, migrations_path: schema_path)
        @intermediate_db.execute("ATTACH DATABASE ? AS #{alias_name}", db_path)
      end

      def optimize_intermediate_db
        @intermediate_db.execute("PRAGMA optimize=0x10002")
      end

      def step_classes
        steps_module = Steps
        classes =
          steps_module
            .constants
            .map { |c| steps_module.const_get(c) }
            .select { |klass| klass.is_a?(Class) && klass < Step }

        filtered_classes = ClassFilter.filter(classes, only: @options[:only], skip: @options[:skip])
        TopologicalSorter.sort(filtered_classes)
      end

      def execute_steps
        classes = step_classes
        # Titles are handed to the reporter up front so it can reserve its title
        # column before any step runs.
        titles = classes.map(&:title)
        @reporter = Reporting::Factory.build(titles:)

        classes.each_with_index do |step_class, index|
          step_report = @reporter.start_step(titles[index])

          step = step_class.new(@intermediate_db, @discourse_db, @shared_data, @config)
          step.reporter = step_report
          begin
            step.execute
          ensure
            step_report.finish
          end
        end
      end

      def cleanup
        @reporter&.close
        @intermediate_db.close
        @discourse_db.close
      end
    end
  end
end
