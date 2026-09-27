# frozen_string_literal: true

module JsonApiKit
  class RemovedDeclarations
    def initialize(changes)
      @changes = changes
    end

    def for(type) = enum_for(:each_for, type)

    private

    attr_reader :changes

    def each_for(type)
      return if changes.empty?

      changes
        .reverse_each
        .zip(types_at_changes(type, changes.reverse_each)) do |change, historical_type|
          each_from(change, historical_type) { yield(it) }
        end
    end

    def each_from(_change, _type)
      raise NotImplementedError, "#{self.class} must implement each_from"
    end

    def types_at_changes(type, changes)
      Enumerator.produce(type) { changes.next.previous_resource_type(it) }
    end
  end
end
