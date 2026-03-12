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
        attach_uploads_db(config[:uploads_db])
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
      end

      private

      def attach_mappings_db(db_path, reset)
        Database.reset!(db_path) if reset
        migrate_and_attach(db_path, Database::MAPPINGS_DB_SCHEMA_PATH, "mapped")
      end

      def attach_uploads_db(db_path)
        migrate_and_attach(db_path, Database::UPLOADS_DB_SCHEMA_PATH, "files")
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
        max = step_classes.size

        step_classes
          .each
          .with_index(1) do |step_class, index|
            puts "#{step_class.title} [#{index}/#{max}]"
            step = step_class.new(@intermediate_db, @discourse_db, @shared_data, @config)
            step.execute
            puts ""
          end
      end

      def cleanup
        @intermediate_db.close
        @discourse_db.close
      end
    end
  end
end
