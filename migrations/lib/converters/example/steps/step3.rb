# frozen_string_literal: true

module Migrations::Converters::Example
  class Step3 < ::Migrations::Converters::Base::ProgressStep
    run_in_parallel true

    def max_progress
      1000
    end

    def items
      (1..1000).map { |i| { counter: i } }
    end

    def process_item(item, stats)
      sleep(0.5)

      IntermediateDB::LogEntry.create!(type: "info", message: "Step3 - #{item[:counter]}")
    end
  end
end
