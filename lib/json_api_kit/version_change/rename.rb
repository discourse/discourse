# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    Rename =
      Data.define(:from, :to, :up, :down) do
        def current = to

        def current_pairs(value) = [[to, up.call(value)]]

        def previous = from

        def previous_pairs(value) = [[from, down.call(value)]]
      end
  end
end
