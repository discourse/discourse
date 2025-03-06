# frozen_string_literal: true

module Migrations::Importer
  class Executor
    def initialize(config)
      @intermediate_db = ::Migrations::Database.connect(config[:intermediate_db])
      @discourse_db = DiscourseDB.new
    end

    def start
      execute_steps
    ensure
      cleanup
    end

    private

    def step_classes
      steps_module = ::Migrations::Importer::Steps
      steps_module
        .constants
        .map { |c| steps_module.const_get(c) }
        .select { |klass| klass.is_a?(Class) }
        .sort_by(&:to_s)
    end

    def execute_steps
      step_classes.each { |step_class| step_class.new(@intermediate_db, @discourse_db).execute }
    end

    def cleanup
      @intermediate_db.close
      @discourse_db.close
    end
  end
end
