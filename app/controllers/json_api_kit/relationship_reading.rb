# frozen_string_literal: true

module JsonApiKit
  module RelationshipReading
    extend ActiveSupport::Concern

    MissingDeclaration = Class.new(StandardError)

    included { class_attribute :declared_relationship, instance_accessor: false }

    class_methods do
      def relationship(declaration)
        name = declaration.to_s.tr("-", "_")
        unless declared_resource
          raise EndpointController::Serving::MissingDeclaration,
                "#{self}: declare the resource before `relationship :#{name}`"
        end
        declared_resource.related_resource(name)
        self.declared_relationship = name
      end
    end

    private

    def render_related_resources
      render_relationship(relationship.related_document)
    end

    def render_linkage
      render_relationship(relationship.linkage_document)
    end

    def render_relationship(document_class)
      render_document(
        document_class.for(
          request.query_parameters,
          resource: relationship.resource,
          client:,
          scoped_to: relationship.scope,
        ),
      )
    end

    def relationship
      @relationship ||=
        Relationship.new(request.path_parameters[:id], relationship_name, resource: owner_resource)
    end

    def relationship_name
      @relationship_name ||= self.class.declared_relationship || route_relationship_name or
        raise MissingDeclaration,
              "#{self.class}: declare the relationship it serves with `relationship :things` or a :relationship route parameter"
    end

    def route_relationship_name
      request.path_parameters[:relationship].presence.try { it.to_s.tr("-", "_") }
    end

    def owner_resource = @owner_resource ||= resource.new(guardian:, edition:)
  end
end
