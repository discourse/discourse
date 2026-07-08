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
      end
    end
  end
end
