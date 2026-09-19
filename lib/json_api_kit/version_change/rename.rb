# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    Rename =
      Data.define(:from, :to, :up, :down) do
        def current = to

        def current_pairs(attributes) = [[to, up.call(attributes[from])]]

        def previous_names = [from]

        def previous_pairs(value) = [[from, down.call(value)]]
      end
  end
end
