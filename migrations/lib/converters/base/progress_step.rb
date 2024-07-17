# frozen_string_literal: true

module Migrations::Converters::Base
  class ProgressStep < Step
    def max_progress
      nil
    end

    def items
      raise NotImplementedError
    end

    def process_item(item, stats)
      raise NotImplementedError
    end

    class << self
      def run_in_parallel(value)
        @run_in_parallel = !!value
      end

      def run_in_parallel?
        @run_in_parallel == true
      end

      def report_progress_in_percent(value)
        @report_progress_in_percent = !!value
      end

      def report_progress_in_percent?
        @report_progress_in_percent == true
      end

      def use_custom_progress_increment(value)
        @use_custom_progress_increment = !!value
      end

      def use_custom_progress_increment?
        @use_custom_progress_increment == true
      end
    end
  end
end
