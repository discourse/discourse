# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    Merge =
      Data.define(:from, :to, :up, :down) do
        def current = to

        def current_pairs(attributes) = [[to, up.call(*attributes.values_at(*from))]]

        def previous_names = from

        def previous_pairs(value) = from.zip(previous_values(value))

        private

        def previous_values(value)
          Array(down.call(value)).tap do |values|
            next if values.size == from.size
            raise ArgumentError,
                  "down: answers #{values.size} #{"value".pluralize(values.size)} for " \
                    "#{from.size} names, to split #{to}."
          end
        end
      end
  end
end
