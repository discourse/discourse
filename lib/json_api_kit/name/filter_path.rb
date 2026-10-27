# frozen_string_literal: true

module JsonApiKit
  module Name
    FilterPath =
      Data.define(:relationships, :filter) do
        def prepend(relationship) = with(relationships: [relationship, *relationships])

        def member_name(glossary)
          [*relationships, filter].map { glossary.member_name(it).value }.join(".")
        end
      end
  end
end
