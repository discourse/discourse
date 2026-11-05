# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    PassThrough =
      Data.define(:name) do
        def current_names = [name]

        def current_pairs(attributes, **) = [[name, attributes[name]]]

        def previous_names = [name]

        def previous_pairs(attributes) = [[name, attributes.fetch(name)]]
      end
  end
end
