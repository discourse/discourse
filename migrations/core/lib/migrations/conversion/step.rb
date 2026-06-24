# frozen_string_literal: true

module Migrations
  module Conversion
    class Step < StepBase
      include AttributeAssignment

      attr_accessor :settings
      attr_reader :tracker

      # inside of Step it might make more sense to access it as `step` instead of `tracker`
      alias step tracker

      def initialize(args = {})
        @tracker = StepTracker.new
        assign_attributes(args)
      end

      def execute
        # do nothing
      end
    end
  end
end
