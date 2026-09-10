# frozen_string_literal: true

module JsonApiKit
  class Request
    class Family
      class Sort < Family
        class TwoDirections < BadParameter
          def initialize(names, parameter: nil)
            @names = names
            super("#{names.join(" and ")} sort by one attribute in two directions.", parameter:)
          end

          def title = "Invalid sort"

          private

          attr_reader :names

          def arguments = [names]
        end

        def declared_value(value, path)
          Keys
            .parse(value, path)
            .try { it.declare { |key| declared_name(sort_name(key.name), key.path) } } || value
        end

        private

        def sort_name(value) = Name::Sort.new(value:, type:)
      end
    end
  end
end
