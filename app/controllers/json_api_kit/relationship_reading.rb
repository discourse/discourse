# frozen_string_literal: true

module JsonApiKit
  module RelationshipReading
    extend ActiveSupport::Concern

    included { rescue_from(Error) { render_document(Document::Errors.new(it)) } }

    private

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
      @relationship ||= Relationship.new(params[:id], params[:relationship], resource:, client:)
    end
  end
end
