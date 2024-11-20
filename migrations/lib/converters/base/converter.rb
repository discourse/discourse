# frozen_string_literal: true

module Migrations::Converters::Base
  class Converter
    attr_accessor :settings

    def initialize(settings)
      @settings = settings
    end

    def run
      if respond_to?(:setup)
        puts "Initializing..."
        setup
      end

      create_database

      steps.each do |step_class|
        step = create_step(step_class)
        before_step_execution(step)
        execute_step(step)
        after_step_execution(step)
      end
    rescue SignalException
      STDERR.puts "\nAborted"
      exit(1)
    ensure
      ::Migrations::Database::IntermediateDB.close
    end

    def steps
      raise NotImplementedError
    end

    def before_step_execution(step)
      # do nothing
    end

    def execute_step(step)
      executor =
        if step.is_a?(ProgressStep)
          ProgressStepExecutor
        else
          StepExecutor
        end

      executor.new(step).execute
    end

    def after_step_execution(step)
      # do nothing
    end

    def step_args(step_class)
      {}
    end

    private

    def create_database
      db_path = File.expand_path(settings[:intermediate_db][:path], ::Migrations.root_path)
      ::Migrations::Database.migrate(
        db_path,
        migrations_path: ::Migrations::Database::INTERMEDIATE_DB_SCHEMA_PATH,
      )

      db = ::Migrations::Database.connect(db_path)
      ::Migrations::Database::IntermediateDB.setup(db)
    end

    def create_step(step_class)
      default_args = { settings: settings }

      args = default_args.merge(step_args(step_class))
      step_class.new(StepTracker.new, args)
    end
  end
end
