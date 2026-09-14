# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    Split =
      Data.define(:from, :to, :up, :down) do
        def current_names = to

        def current_pairs(attributes) = to.zip(current_values(attributes.fetch(from)))

        def previous_names = [from]

        def previous_pairs(attributes)
          return [] unless to.all? { attributes.key?(it) }
          [[from, down.call(*attributes.values_at(*to))]]
        end

        private

        def current_values(value)
          Array(up.call(value)).tap do |values|
            next if values.size == to.size
            raise ArgumentError,
                  "up: answers #{values.size} #{"value".pluralize(values.size)} for " \
                    "#{to.size} names, to split #{from}."
          end
        end
      end
  end
end
