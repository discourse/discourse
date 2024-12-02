# frozen_string_literal: true

module Migrations::Converters::Example
  class Step2 < ::Migrations::Converters::Base::ProgressStep
    run_in_parallel false

    def items
      [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    end

    def process_item(item)
      sleep(0.5)

      step.log_warning("Test", details: item) if item.in?([3, 7, 9])
      step.log_error("Test", details: item) if item.in?([6, 10])

      IntermediateDB::LogEntry.create!(type: "info", message: "Step2 - #{item}")
    end
  end
end
