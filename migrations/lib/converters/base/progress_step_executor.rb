# frozen_string_literal: true

require "etc"
require "colored2"

module Migrations::Converters::Base
  class ProgressStepExecutor
    WORKER_COUNT = Etc.nprocessors - 1 # leave 1 CPU free to do other work
    MIN_PARALLEL_ITEMS = WORKER_COUNT * 10
    MAX_QUEUE_SIZE = WORKER_COUNT * 100
    PRINT_RUNTIME_AFTER_SECONDS = 5

    def initialize(step)
      @step = step
    end

    def execute
      @max_progress = calculate_max_progress

      puts @step.class.title
      @step.execute

      if execute_in_parallel?
        execute_parallel
      else
        execute_serially
      end
    end

    private

    def execute_in_parallel?
      @step.class.run_in_parallel? && (@max_progress.nil? || @max_progress > MIN_PARALLEL_ITEMS)
    end

    def execute_serially
      job = SerialJob.new(@step)

      with_progressbar do |progressbar|
        @step.items.each do |item|
          stats = job.run(item)
          progressbar.update(stats.progress, stats.warning_count, stats.error_count)
        end
      end
    end

    def execute_parallel
      worker_output_queue = SizedQueue.new(MAX_QUEUE_SIZE)
      work_queue = SizedQueue.new(MAX_QUEUE_SIZE)

      workers = start_workers(work_queue, worker_output_queue)
      writer_thread = start_db_writer(worker_output_queue)
      push_work(work_queue)

      workers.each(&:wait)
      worker_output_queue.close
      writer_thread.join
    end

    def calculate_max_progress
      start_time = Time.now
      max_progress = @step.max_progress
      duration = Time.now - start_time

      if duration > PRINT_RUNTIME_AFTER_SECONDS
        message =
          I18n.t(
            "converter.max_progress_calculation",
            duration: ::Migrations::DateHelper.human_readable_time(duration),
          )
        puts "    #{message}"
      end

      max_progress
    end

    def with_progressbar
      ::Migrations::ExtendedProgressBar
        .new(max_progress: @max_progress)
        .run { |progressbar| yield progressbar }
    end

    def start_db_writer(worker_output_queue)
      Thread.new do
        Thread.current.name = "writer_thread"

        with_progressbar do |progressbar|
          while (parametrized_insert_statements, stats = worker_output_queue.pop)
            parametrized_insert_statements.each do |sql, parameters|
              ::Migrations::Database::IntermediateDB.insert(sql, *parameters)
            end

            progressbar.update(stats.progress, stats.warning_count, stats.error_count)
          end
        end
      end
    end

    def start_workers(work_queue, worker_output_queue)
      workers = []

      Process.warmup

      ::Migrations::ForkManager.batch_forks do
        WORKER_COUNT.times do |index|
          job = ParallelJob.new(@step)
          workers << Worker.new(index, work_queue, worker_output_queue, job).start
        end
      end

      workers
    end

    def push_work(work_queue)
      @step.items.each { |item| work_queue.push(item) }
      work_queue.close
    end
  end
end
