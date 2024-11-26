# frozen_string_literal: true

module Migrations::Converters::Base
  class StepTracker
    attr_reader :stats

    def initialize
      @stats = StepStats.new
      reset_stats!
    end

    def reset_stats!
      @stats.progress = 1
      @stats.warning_count = 0
      @stats.error_count = 0
    end

    def progress=(value)
      @stats.progress = value
    end

    def log_info(message, details: nil)
      log(::Migrations::Database::IntermediateDB::LogEntry::INFO, message, details:)
    end

    def log_warning(message, exception: nil, details: nil)
      @stats.warning_count += 1
      log(::Migrations::Database::IntermediateDB::LogEntry::WARNING, message, exception:, details:)
    end

    def log_error(message, exception: nil, details: nil)
      @stats.error_count += 1
      log(::Migrations::Database::IntermediateDB::LogEntry::ERROR, message, exception:, details:)
    end

    private

    def log(type, message, exception: nil, details: nil)
      ::Migrations::Database::IntermediateDB::LogEntry.create!(
        type:,
        message:,
        exception:,
        details:,
      )
    end
  end
end
