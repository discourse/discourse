# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    class Converter
      class Tuple < Converter
        class InvalidResult < ArgumentError
          attr_reader :names

          def initialize(direction, names, message)
            @direction = direction
            @names = names
            super(message)
          end

          def up? = direction == :up

          def convert_names(&) = self.class.new(direction, names.flat_map(&).uniq, message)

          private

          attr_reader :direction
        end

        def initialize(direction, callable, names, to:)
          @destinations = to
          super(direction, callable, names)
        end

        def call(...)
          Array(super).tap do |values|
            next if values.size == destinations.size
            raise InvalidResult.new(
                    direction,
                    names,
                    "#{direction} converter for #{names.join(", ")} must return " \
                      "#{destinations.size} #{"value".pluralize(destinations.size)} " \
                      "(#{destinations.join(", ")}). It returned #{values.size}.",
                  )
          end
        end

        private

        attr_reader :destinations
      end
    end
  end
end
