# frozen_string_literal: true

module Migrations
  module Conversion
    class Base
      attr_accessor :settings

      def initialize(settings)
        @settings = settings
      end

      def run(only_steps: [], skip_steps: [], max_parallel_steps: nil, no_fork: false)
        if respond_to?(:setup)
          puts "Initializing..."
          setup
        end

        create_database

        # Titles are known from the step classes (no instantiation, no queries),
        # so the reporter can reserve its title column up front. The steps
        # themselves are built and sized lazily. Each step's source is opened
        # and counted in its own fork when it runs.
        step_classes = filter_steps(steps, only_steps, skip_steps)
        @reporter = Reporting::Factory.build(titles: step_classes.map(&:title))

        StepScheduler.new(
          step_classes:,
          reporter: @reporter,
          step_factory: method(:create_step),
          shard_manager: @shard_manager,
          writer: @writer,
          budget: WorkerBudget.available, # usable CPUs minus one for the parent + merges
          max_parallel_steps:,
          no_fork:,
        ).run
      rescue SignalException
        @aborted = true
        exit(130)
      ensure
        # An optional converter hook (like `setup`), run while the run DB and reporter
        # are still live, so a converter can query the log entries it wrote and print
        # a hint under the summary. Skipped on an abort — the user asked to stop.
        if @writer && @reporter && !@aborted && respond_to?(:report_diagnostics)
          report_diagnostics(@writer, @reporter)
        end
        Database::IntermediateDB.close
        @shard_manager&.cleanup
        # Restore the terminal (and flush the final frame) before printing the
        # run-level abort line, so it lands cleanly below the reporter output
        # instead of fighting the live region.
        @reporter&.close
        STDERR.puts "\n#{I18n.t("cli.aborted")}" if @aborted
      end

      def steps
        step_class = Step
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

      def step_args(step_class)
        {}
      end

      private

      def create_database
        db_path = File.expand_path(settings[:intermediate_db][:path], Migrations.root_path)
        Database.migrate(db_path, migrations_path: Database::INTERMEDIATE_DB_SCHEMA_PATH)

        @shard_manager =
          ShardManager.new(
            canonical_path: db_path,
            migrations_path: Database::INTERMEDIATE_DB_SCHEMA_PATH,
          )
        @writer = Database::Connection.new(path: db_path)
        Database::IntermediateDB.setup(@writer)
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
