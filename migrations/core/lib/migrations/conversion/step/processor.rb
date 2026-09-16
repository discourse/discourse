# frozen_string_literal: true

module Migrations
  module Conversion
    class Step
      class Processor
        include AttributeAssignment

        attr_accessor :settings
        attr_reader :tracker

        class << self
          # Hand the items to `process_batch` in slices of `size` instead of one
          # at a time. For a processor whose per-item cost is dominated by a
          # call it can make once for many items (an external engine, a bulk
          # lookup); anything else is cheaper per item and should stay on
          # `process`. Called without a value it reads the declared size back.
          def batch_size(value = nil)
            return @batch_size if value.nil?

            unless value.is_a?(Integer) && value > 0
              raise ArgumentError, "`batch_size` must be a positive integer"
            end

            @batch_size = value
          end

          def batched?
            !batch_size.nil?
          end
        end

        def initialize(args = {})
          @tracker = StepTracker.new
          assign_attributes(args)
        end

        def setup
        end

        def process(item)
          raise NotImplementedError
        end

        # The batched counterpart of `process`, called once per slice when the
        # processor declares a `batch_size`. Progress counts the whole slice
        # unless the method sets `tracker.progress=` itself, and an exception
        # loses the slice, not the step — so a processor that can tell one bad
        # item from the rest handles its own errors per item and lets this
        # rescue catch only what breaks the batch as a whole.
        def process_batch(items)
          raise NotImplementedError
        end

        # Optional map/reduce hook. The worker calls this once, after its items are
        # exhausted, and hands the value back to the parent, where the step's
        # `combine_results(results, tracker)` receives an array of them (one per
        # worker that returned non-nil) plus a StepTracker to log through —
        # whatever it logs feeds the step's warning/error tallies. Return nil (the
        # default) to hand back nothing.
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
