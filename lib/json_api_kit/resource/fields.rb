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

        def attribute(...)
          self.declared_attributes = declared_attributes + [Declarations::Attribute.new(...)]
        end

        def has_one(name, **options) = relate(Declarations::Relationship::ToOne, name, **options)

        def has_many(name, **options) = relate(Declarations::Relationship::ToMany, name, **options)

        def attribute_names = declared_attributes.map(&:name)

        def writable_attributes = declared_attributes.select(&:writable?)

        def relationships = Declarations::Relationships.new(declared_relationships)

        def related_resource(name)
          relationships
            .fetch(name.to_s) do
              raise UnknownRelationship, "There is no relationship named #{name}."
            end
            .resource
        end

        def fields(names = nil, guardian:)
          Declarations::Fields.for(
            names,
            guardian:,
            attributes: declared_attributes,
            relationships: declared_relationships,
            type:,
          )
        end

        private

        def relate(kind, name, resource: nil, **options)
          self.declared_relationships =
            declared_relationships +
              [
                kind.new(
                  name,
                  resource: ResourceLookup.resource(resource || name, within: self),
                  **options,
                ),
              ]
        end
      end

      delegate :attribute_names,
               :writable_attributes,
               :relationships,
               :fields,
               :resolves?,
               to: :class

      def attribute_value(name, record:)
        unless name.type == type && attribute_names.include?(name.value)
          raise KeyError, "#{name} is not an attribute of #{type}."
        end
        fields([name.value], guardian:)
          .attributes
          .values_for(record)
          .fetch(name) do
            raise UnreadableAttribute, "The existing value of #{name} is not readable."
          end
      end
    end
  end
end
