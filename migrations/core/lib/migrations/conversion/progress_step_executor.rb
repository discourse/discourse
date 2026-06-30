# frozen_string_literal: true

module Migrations
  module Conversion
    class ProgressStepExecutor
      PRINT_RUNTIME_AFTER_SECONDS = 5

      def initialize(step, pool:, reporter:)
        @step = step
        @source = step.source
        @pool = pool
        @reporter = reporter
      end

      def execute
        @step_report = @reporter.start_step(@step.class.title)
        @max_progress = calculate_max_progress

        if execute_in_parallel?
          execute_parallel
        else
          execute_serially
        end
      ensure
        @step_report.finish
      end

      private

      # Parallelism only pays off above a minimum number of items, and the
      # queues need bounds for backpressure. Both are executor policy, scaled
      # by the size of the injected pool.
      def min_parallel_items
        @pool.size * 10
      end

      def max_queue_size
        @pool.size * 100
      end

      def execute_in_parallel?
        @step.class.run_in_parallel? && (@max_progress.nil? || @max_progress > min_parallel_items)
      end

      def execute_serially
        job = SerialJob.new(@step.create_processor)
        job.setup

        @step_report.with_progress(max_progress: @max_progress) do |progress|
          @source.items.each do |item|
            stats = job.run(item)
            progress.update(
              increment_by: stats.progress,
              warning_count: stats.warning_count,
              error_count: stats.error_count,
            )
          end
        end
      end

      def execute_parallel
        worker_output_queue = SizedQueue.new(max_queue_size)
        work_queue = SizedQueue.new(max_queue_size)

        batch =
          @pool.start(work_queue:, output_queue: worker_output_queue) do
            ParallelJob.new(@step.create_processor)
          end
        writer_thread = start_db_writer(worker_output_queue)
        push_work(work_queue)

        batch.wait
        worker_output_queue.close
        writer_thread.join
      end

      def calculate_max_progress
        start_time = Time.now
        max_progress = @source.max_progress
        duration = Time.now - start_time

        if duration > PRINT_RUNTIME_AFTER_SECONDS
          @step_report.notice(
            I18n.t(
              "converter.max_progress_calculation",
              duration: DateHelper.human_readable_time(duration),
            ),
          )
        end

        max_progress
      end

      def start_db_writer(worker_output_queue)
        Thread.new do
          Thread.current.name = "writer_thread"

          @step_report.with_progress(max_progress: @max_progress) do |progress|
            while (parametrized_insert_statements, stats = worker_output_queue.pop)
              parametrized_insert_statements.each do |sql, parameters|
                Database::IntermediateDB.insert(sql, *parameters)
              end

              progress.update(
                increment_by: stats.progress,
                warning_count: stats.warning_count,
                error_count: stats.error_count,
              )
            end
          end
        end
      end

      def push_work(work_queue)
        @source.items.each { |item| work_queue.push(item) }
        work_queue.close
      end
    end
  end
end
