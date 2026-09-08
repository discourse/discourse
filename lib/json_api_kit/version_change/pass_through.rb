# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    PassThrough =
      Data.define(:name) do
        def current = name

        def current_pairs(attributes) = [[name, attributes[name]]]

        def previous_names = [name]

        def previous_pairs(value) = [[name, value]]
      end
  end
end
