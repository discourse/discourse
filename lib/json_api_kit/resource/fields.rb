# frozen_string_literal: true

module JsonApiKit
  class Resource
    module Fields
      extend ActiveSupport::Concern

      included do
        class_attribute :declared_attributes,
                        default: [].freeze,
                        instance_accessor: false,
                        instance_predicate: false
        class_attribute :declared_relationships,
                        default: [].freeze,
                        instance_accessor: false,
                        instance_predicate: false
        private_class_method :declared_attributes,
                             :declared_attributes=,
                             :declared_relationships,
                             :declared_relationships=
      end

      class_methods do
        delegate :resolves?, to: :relationships

        def attribute(name, &value)
          self.declared_attributes =
            declared_attributes + [Declarations::Attribute.new(name, &value)]
        end

        def has_one(name, resource:)
          relate(Declarations::Relationship::ToOne.new(name, resource:))
        end

        def has_many(name, resource:)
          relate(Declarations::Relationship::ToMany.new(name, resource:))
        end

        def fields(names = nil)
          Declarations::Fields.for(
            names,
            attributes: declared_attributes,
            relationships: declared_relationships,
            schema:,
          )
        end

        private

        def relationships = Declarations::Relationships.new(declared_relationships)

        def relate(relationship)
          self.declared_relationships = declared_relationships + [relationship]
        end
      end
    end
  end
end
