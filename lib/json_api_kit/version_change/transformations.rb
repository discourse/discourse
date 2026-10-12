# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    class Transformations < NameChanges
      def current_values(attributes)
        current_changes(attributes.keys).flat_map { it.current_pairs(attributes) }.to_h
      end

      def previous_values(attributes)
        previous_changes(attributes.keys).flat_map { it.previous_pairs(attributes) }.to_h
      end
    end
  end
end
