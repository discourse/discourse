# frozen_string_literal: true

module JsonApiKit
  class RelationshipPaths
    Position =
      Data.define(:resource, :glossary) do
        delegate :declared_relationship, :member_relationship, to: :glossary, private: true

        def advance_to_declared(member:)
          step(declared_relationship(member:, type: resource.type))
        end

        def advance_to_member(declared:)
          step(declared, name: member_relationship(declared:, type: resource.type))
        rescue UnknownPath
          UnscopedPosition.new(glossary:).advance_to_member(declared:)
        end

        private

        def step(relationship_name, name: relationship_name)
          Step.new(name:, next_position: with(resource: relationship(relationship_name).resource))
        end

        def relationship(name)
          resource.relationships.fetch(name) { raise UnknownPath.new(name) }
        end
      end
  end
end
