# frozen_string_literal: true

module Migrations::Converters::Base
  class ProgressStats
    attr_accessor :progress, :warning_count, :error_count

    def initialize
      reset!
    end

    def reset!
      @progress = 1
      @warning_count = 0
      @error_count = 0
    end

    def log_info(message, details: nil)
      log(::Migrations::Database::IntermediateDB::LogEntry::INFO, message, details:)
    end

    def log_warning(message, exception: nil, details: nil)
      @warning_count += 1
      log(::Migrations::Database::IntermediateDB::LogEntry::WARNING, message, exception:, details:)
    end

    def log_error(message, exception: nil, details: nil)
      @error_count += 1
      log(::Migrations::Database::IntermediateDB::LogEntry::ERROR, message, exception:, details:)
    end

    def ==(other)
      other.is_a?(ProgressStats) && progress == other.progress &&
        warning_count == other.warning_count && error_count == other.error_count
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
