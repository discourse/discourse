# frozen_string_literal: true

module Migrations::Importer
  class Executor
    def initialize(config)
      @intermediate_db = ::Migrations::Database.connect(config[:intermediate_db])
      @discourse_db = DiscourseDB.new
      @shared_data = SharedData.new(@discourse_db)

      attach_mappings_db(config[:mappings_db])
    end

    def start
      execute_steps
    ensure
      cleanup
    end

    private

    def attach_mappings_db(db_path)
      ::Migrations::Database.reset!(db_path)
      ::Migrations::Database.migrate(
        db_path,
        migrations_path: ::Migrations::Database::MAPPINGS_DB_SCHEMA_PATH,
      )
      @intermediate_db.execute("ATTACH DATABASE ? AS mapped", db_path)
    end

    def step_classes
      steps_module = ::Migrations::Importer::Steps
      classes =
        steps_module
          .constants
          .map { |c| steps_module.const_get(c) }
          .select { |klass| klass.is_a?(Class) && klass < ::Migrations::Importer::Step }
      TopologicalSorter.sort(classes)
    end

    def execute_steps
      step_classes.each do |step_class|
        step = step_class.new(@intermediate_db, @discourse_db, @shared_data)
        step.execute
      end
    end

    def cleanup
      @intermediate_db.close
      @discourse_db.close
    end
  end
end
