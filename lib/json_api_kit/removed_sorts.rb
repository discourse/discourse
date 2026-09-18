# frozen_string_literal: true

module JsonApiKit
  class RemovedSorts
    def initialize(changes)
      @changes = changes
    end

    def for(type) = enum_for(:each_removed_sort, type)

    private

    attr_reader :changes

    def each_removed_sort(type)
      return if changes.empty?

      changes
        .reverse_each
        .zip(types_at_changes(type, changes.reverse_each)) do |change, historical_type|
          change.each_removed_sort(historical_type) { yield(it) }
        end
    end

    def types_at_changes(type, changes)
      Enumerator.produce(type) { changes.next.previous_resource_type(it) }
    end
  end
end
