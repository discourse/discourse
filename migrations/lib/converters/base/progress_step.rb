# frozen_string_literal: true

module Migrations::Converters::Base
  class ProgressStep < Step
    def max_progress
      nil
    end

    def items
      raise NotImplementedError
    end

    def process_item(item)
      raise NotImplementedError
    end

    class << self
      def run_in_parallel(value)
        @run_in_parallel = !!value
      end

      def run_in_parallel?
        @run_in_parallel == true
      end
    end
  end
end
