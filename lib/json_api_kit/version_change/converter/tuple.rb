# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    class Converter
      class Tuple < Converter
        def initialize(direction, callable, names, to:)
          @destinations = to
          super(direction, callable, names)
        end

        def call(...)
          Array(super).tap do |values|
            next if values.size == destinations.size
            raise ArgumentError,
                  "#{direction} converter for #{names.join(", ")} must return " \
                    "#{destinations.size} #{"value".pluralize(destinations.size)} " \
                    "(#{destinations.join(", ")}). It returned #{values.size}."
          end
        end

        private

        attr_reader :destinations
      end
    end
  end
end
