# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    TypeRename =
      Data.define(:from, :to) do
        def current = to

        def previous_names = [from]
      end
  end
end
