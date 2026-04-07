# frozen_string_literal: true

module DiscourseWorkflows
  class WaitForTimer < WaitForResume
    attr_reader :wait_amount, :wait_unit, :wait_duration_seconds

    def initialize(wait_amount:, wait_unit:, wait_duration_seconds:)
      @wait_amount = wait_amount
      @wait_unit = wait_unit
      @wait_duration_seconds = wait_duration_seconds
      super(type: :timer, message: "Workflow paused waiting for timer (#{wait_amount} #{wait_unit})")
    end
  end
end
