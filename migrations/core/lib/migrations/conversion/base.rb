# frozen_string_literal: true

module Migrations
  module Conversion
    class Base
      attr_accessor :settings

      def initialize(settings)
        @settings = settings
      end

      def run(only_steps: [], skip_steps: [])
        if respond_to?(:setup)
          puts "Initializing..."
          setup
        end

        create_database

        @worker_pool = WorkerPool.new
        @reporter = ConsoleReporter.new

        filter_steps(steps, only_steps, skip_steps).each do |step_class|
          step = create_step(step_class)
          before_step_execution(step)
          execute_step(step)
          after_step_execution(step)
        end
      rescue SignalException
        STDERR.puts "\nAborted"
        exit(1)
      ensure
        Database::IntermediateDB.close
      end

      def steps
        step_class = StepBase
        current_module = self.class.name.deconstantize.constantize

        classes =
          current_module
            .constants
            .map { |c| current_module.const_get(c) }
            .select { |klass| klass.is_a?(Class) && klass < step_class }

        # Unlike the importer, the full step set is sorted here and the
        # `--only`/`--skip` filtering happens afterwards (see `filter_steps` in
        # `run`). This is intentional: re-running a single step via `--only`
        # has to keep working even when that step declares dependencies.
        TopologicalSorter.sort(classes)
      end

      def before_step_execution(step)
        # do nothing
      end

      def execute_step(step)
        executor =
          if step.is_a?(ProgressStep)
            ProgressStepExecutor.new(step, pool: @worker_pool, reporter: @reporter)
          else
            StepExecutor.new(step, reporter: @reporter)
          end

        executor.execute
      end

      def after_step_execution(step)
        # do nothing
      end

      def step_args(step_class)
        {}
      end

      private

      def create_database
        db_path = File.expand_path(settings[:intermediate_db][:path], Migrations.root_path)
        Database.migrate(db_path, migrations_path: Database::INTERMEDIATE_DB_SCHEMA_PATH)

        db = Database.connect(db_path)
        Database::IntermediateDB.setup(db)
      end

      def create_step(step_class)
        default_args = { settings: }

        args = default_args.merge(step_args(step_class))
        step_class.new(args)
      end

      def filter_steps(step_classes, only_steps, skip_steps)
        ClassFilter.filter(step_classes, only: only_steps, skip: skip_steps)
      end
    end
  end
end
