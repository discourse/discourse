# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    Split =
      Data.define(:from, :to, :up, :down) do
        def current_names = to

        def current_pairs(attributes) = to.zip(up.call(attributes.fetch(from)))

        def previous_names = [from]

        def previous_pairs(attributes)
          return [] unless to.all? { attributes.key?(it) }
          [[from, down.call(*attributes.values_at(*to))]]
        end
      end
  end
end
