# frozen_string_literal: true

module JsonApiKit
  module RelationshipReading
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
      @relationship ||= Relationship.new(params[:id], relationship_name, resource: owner_resource)
    end

    def relationship_name = params[:relationship].tr("-", "_")

    def owner_resource = resource.new(guardian:, edition:)
  end
end
