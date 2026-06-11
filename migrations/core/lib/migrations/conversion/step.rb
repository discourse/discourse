# frozen_string_literal: true

module Migrations
  module Conversion
    class Step
      # These constants also make bare `IntermediateDB::...` / `Enums::...`
      # references work inside `ProgressStep`'s `source` / `processor` blocks:
      # the blocks are written in step class bodies, and constants in methods
      # defined via `class_eval(&block)` resolve through the block's lexical
      # scope — the step class and its ancestors — not the role class.
      IntermediateDB = Database::IntermediateDB
      Enums = Database::IntermediateDB::Enums

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

      class << self
        def title(
          value = (
            getter = true
            nil
          )
        )
          @title = value unless getter
          @title.presence ||
            I18n.t(
              "converter.default_step_title",
              type: name&.demodulize&.underscore&.humanize(capitalize: false),
            )
        end
      end
    end
  end
end
