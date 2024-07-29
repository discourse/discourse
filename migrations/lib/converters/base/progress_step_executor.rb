# frozen_string_literal: true

require "etc"

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
  end
end
