# frozen_string_literal: true

require "etc"
require "colored2"

module Migrations::Converters::Base
  class ProgressStepExecutor
    WORKER_COUNT = Etc.nprocessors
    MIN_PARALLEL_ITEMS = WORKER_COUNT * 10
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
    end

    def calculate_max_progress
      start_time = Time.now
      max_progress = @step.max_progress
      duration = Time.now - start_time

      if duration > PRINT_RUNTIME_AFTER_SECONDS
        puts "    Calculating items took #{Migrations::DateHelper.human_readable_time(duration)}"
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
  end
end
