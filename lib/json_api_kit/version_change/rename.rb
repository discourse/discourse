# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    Rename =
      Data.define(:from, :to, :up, :down) do
        def current_names = [to]

        def current_pairs(attributes) = [[to, up.call(attributes[from])]]

        def previous_names = [from]

        def previous_pairs(attributes) = [[from, down.call(attributes.fetch(to))]]
      end
  end
end
