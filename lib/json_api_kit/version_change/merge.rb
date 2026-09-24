# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    Merge =
      Data.define(:from, :to, :up, :down) do
        def current_names = [to]

        def current_pairs(attributes) = [[to, up.call(*attributes.values_at(*from))]]

        def previous_names = from

        def previous_pairs(attributes) = from.zip(down.call(attributes.fetch(to)))
      end
  end
end
