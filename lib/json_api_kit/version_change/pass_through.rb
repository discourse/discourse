# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    PassThrough =
      Data.define(:name) do
        def current = name

        def current_pairs(value) = [[name, value]]

        def previous = name

        def previous_pairs(value) = [[name, value]]
      end
  end
end
