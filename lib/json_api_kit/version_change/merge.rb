# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    Merge =
      Data.define(:from, :to, :up, :down) do
        def current_names = [to]

        def current_pairs(attributes, existing: ExistingValues::None)
          [[to, up.call(*complete(attributes, existing).values_at(*from))]]
        end

        def previous_names = from

        def previous_pairs(attributes) = source_pairs(attributes.fetch(to))

        private

        def source_pairs(value) = from.zip(down.call(value))

        def complete(attributes, existing)
          return attributes if from.all? { attributes.key?(it) }
          current = existing.fetch(to) { return attributes }
          source_pairs(current).to_h.merge(attributes)
        rescue Converter::Failure => error
          raise ExistingValues::ConversionFailure, error.message
        end
      end
  end
end
