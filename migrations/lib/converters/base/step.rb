# frozen_string_literal: true

module Migrations
  module Converters
    module Base
      class Step
        IntermediateDB = Database::IntermediateDB
        Enums = Database::IntermediateDB::Enums

        attr_accessor :settings
        attr_reader :tracker

        # inside of Step it might make more sense to access it as `step` instead of `tracker`
        alias step tracker

        def initialize(tracker, args = {})
          @tracker = tracker

          args.each do |arg, value|
            setter = "#{arg}=".to_sym
            public_send(setter, value) if respond_to?(setter, true)
          end
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
end
