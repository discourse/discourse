# frozen_string_literal: true

require "etc"
require "colored2"
require "ruby-progressbar"

module Migrations::Converters
  class ProgressStepExecutor
    WORKER_COUNT = Etc.nprocessors
    MIN_PARALLEL_ITEMS = WORKER_COUNT * 10
    MAX_QUEUE_SIZE = WORKER_COUNT * 10

    def initialize(step)
      @step = step
    end

    def execute
      @warnings = 0
      @errors = 0
      @extra_information = ""
      @max_progress = calculate_max_progress

      if @step.class.run_in_parallel? && (@max_progress.nil? || @max_progress > MIN_PARALLEL_ITEMS)
        execute_parallel
      else
        execute_serially
      end
    end

    private

    def calculate_max_progress
      start_time = Time.now
      max_progress = @step.max_progress
      duration = Time.now - start_time

      puts "    Calculating items took #{DateHelper.human_readable_time(duration)}" if duration > 5

      max_progress
    end

    def execute_parallel
      progress_queue = Queue.new
      progress_thread =
        Thread.new do
          Thread.current.name = "progress_thread"
          with_progressbar do |progressbar|
            while (stats = progress_queue.pop)
              update_progressbar(progressbar, stats)
            end
          end
        end

      GC.start # a little bit of cleanup before we start forking

      @step.output_db.close

      work_queue = SizedQueue.new(MAX_QUEUE_SIZE)
      workers_threads = []
      worker_output_db_paths = []

      WORKER_COUNT.times do |index|
        db_path = File.join(Convert.output_tmp_dir, "worker_#{index}.db")
        item_handler = ItemHandler.new(@step, db_path)
        OutputDatabase.migrate(path: db_path)
        worker_output_db_paths << db_path

        workers_threads << Worker.new(index, work_queue, item_handler, progress_queue).start
      end

      @step.items.each { |item| work_queue.push(item) }
      work_queue.close

      @step.output_db.reconnect

      workers_threads.each(&:join)
      progress_queue.close
      progress_thread.join

      merge_output_dbs(worker_output_db_paths)
    end

    def execute_serially
      item_handler = ItemHandler.new(@step)

      with_progressbar do |progressbar|
        @step.items.each do |item|
          stats = item_handler.handle(item)
          update_progressbar(progressbar, stats)
        end
      end
    end

    def update_progressbar(progressbar, stats)
      changed = false

      if stats.warning_count > 0
        @warnings += stats.warning_count
        changed = true
      end

      if stats.error_count > 0
        @errors += stats.error_count
        changed = true
      end

      if changed
        @extra_information = +""
        @extra_information << " | " << "#{@warnings} warnings".yellow if @warnings > 0
        @extra_information << " | " << ("#{@errors} errors").red if @errors > 0
        progressbar.format = "#{@base_format}#{@extra_information}"
      end

      if @step.class.use_custom_progress_increment?
        progressbar.progress += stats.progress
      else
        progressbar.increment
      end
    end

    def with_progressbar
      format =
        if @step.class.report_progress_in_percent?
          "Processed: %J%"
        elsif @max_progress
          "Processed: %c / %C"
        else
          "Processed: %c"
        end

      @base_format = @max_progress ? "    %a |%E | #{format}" : "    %a | #{format}"

      progressbar =
        ProgressBar.create(
          total: @max_progress,
          autofinish: false,
          projector: {
            type: "smoothing",
            strength: 0.5,
          },
          format: @base_format,
          throttle_rate: 0.5,
        )

      yield progressbar

      print "\033[K" # delete the output of progressbar, because it doesn't overwrite longer lines
      final_format = @max_progress ? "    %a | #{format}" : "    %a | #{format}"
      progressbar.format = "#{final_format}#{@extra_information}"
      progressbar.finish
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
