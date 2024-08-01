# frozen_string_literal: true

require "etc"
require "colored2"

module Migrations::Converters::Base
  class ProgressStepExecutor
    WORKER_COUNT = Etc.nprocessors
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
      item_handler = ItemHandler.new(@step)

      with_progressbar do |progressbar|
        @step.items.each do |item|
          stats = item_handler.handle(item)
          progressbar.update(stats)
        end
      end
    end

    def execute_parallel
      progress_queue = Queue.new
      progress_thread =
        Thread.new do
          Thread.current.name = "progress_thread"
          with_progressbar do |progressbar|
            while (stats = progress_queue.pop)
              progressbar.update(stats)
            end
          end
        end

      Process.warmup

      work_queue = SizedQueue.new(MAX_QUEUE_SIZE)
      workers_threads = []
      worker_output_db_paths = []

      db_root_path = File.join(File.dirname(::Migrations::Database::IntermediateDB.path), "temp")

      WORKER_COUNT.times do |index|
        db_path = File.join(db_root_path, "worker_#{index}.db")
        ::Migrations::Database.migrate(
          db_path,
          migrations_path: Migrations::Database::INTERMEDIATE_DB_SCHEMA_PATH,
        )

        item_handler = ItemHandler.new(@step, db_path)
        worker_output_db_paths << db_path

        workers_threads << Worker.new(index, work_queue, progress_queue, item_handler).start
      end

      @step.items.each { |item| work_queue.push(item) }
      work_queue.close

      @step.output_db.reconnect

      workers_threads.each(&:join)
      progress_queue.close
      progress_thread.join

      merge_output_dbs(worker_output_db_paths)
    end

    def calculate_max_progress
      start_time = Time.now
      max_progress = @step.max_progress
      duration = Time.now - start_time

      if duration > PRINT_RUNTIME_AFTER_SECONDS
        message =
          I18n.t(
            "converter.max_progress_calculation",
            duration: Migrations::DateHelper.human_readable_time(duration),
          )
        puts "    #{message}"
      end

      max_progress
    end

    def with_progressbar
      ::Migrations::ExtendedProgressBar
        .new(
          max_progress: @max_progress,
          report_progress_in_percent: @step.class.report_progress_in_percent?,
          use_custom_progress_increment: @step.class.use_custom_progress_increment?,
        )
        .run { |progressbar| yield progressbar }
    end

    def merge_output_dbs(worker_output_db_paths)
      print "    Merging output databases...\r"
      start_time = Time.now

      @step.output_db.copy_from(worker_output_db_paths)
      worker_output_db_paths.each { |path| OutputDatabase.reset!(path: path) }

      puts "    Merging output databases: #{DateHelper.human_readable_time(Time.now - start_time)}"
    end
  end
end
