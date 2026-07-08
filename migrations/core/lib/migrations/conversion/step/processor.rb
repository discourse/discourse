# frozen_string_literal: true

module Migrations
  module Conversion
    class Step
      class Processor
        include AttributeAssignment

        attr_accessor :settings
        attr_reader :tracker

        def initialize(args = {})
          @tracker = StepTracker.new
          assign_attributes(args)
        end

        def setup
        end

        def process(item)
          raise NotImplementedError
        end

        # Optional map/reduce hook. The worker calls this once, after its items are
        # exhausted, and hands the value back to the parent, where the step's
        # `combine_results` receives an array of them (one per worker that returned
        # non-nil). Return nil (the default) to hand back nothing.
        #
        # The value crosses a process boundary as JSON, so it must be
        # JSON-serializable and comes back with string keys — even inline, where the
        # parent normalises it the same way, so a step reads its results the same in
        # both modes.
        def result
          nil
        end
      end
    end
  end
end
