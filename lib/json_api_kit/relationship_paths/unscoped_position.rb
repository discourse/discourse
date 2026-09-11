# frozen_string_literal: true

module JsonApiKit
  class RelationshipPaths
    UnscopedPosition =
      Data.define(:glossary) do
        delegate :unscoped_member, to: :glossary, private: true

        def advance_to_member(declared:)
          Step.new(name: unscoped_member(declared:), next_position: self)
        end
      end
  end
end
