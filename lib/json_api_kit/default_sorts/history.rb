# frozen_string_literal: true

module JsonApiKit
  class DefaultSorts
    class History
      def initialize(resource:, changes:)
        @resource = resource
        @changes = changes
      end

      def ordering
        each_historical_default do |default, later_changes|
          return resource.default_ordering(current_ordering(default, through: later_changes))
        end
        resource.default_ordering
      end

      private

      attr_reader :resource, :changes

      def each_historical_default
        return if changes.empty?

        changes
          .each_with_index
          .zip(types_after_changes(changes.each)) do |(change, index), type|
            change.each_current_default_sort(type) do |default|
              yield(default, changes.drop(index + 1))
            end
          end
      end

      def types_after_changes(changes)
        Enumerator.produce(changes.next.current_resource_type(type_at_pin)) do |type|
          changes.next.current_resource_type(type)
        end
      end

      def type_at_pin
        changes
          .reverse_each
          .reduce(resource.type) { |name, change| change.previous_resource_type(name) }
      end

      def current_ordering(historical_default, through:)
        through
          .reduce(historical_default) { |default, change| change.current_default_sort(default) }
          .ordering
      end
    end
  end
end
