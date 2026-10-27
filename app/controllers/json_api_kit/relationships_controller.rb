# frozen_string_literal: true

module JsonApiKit
  class RelationshipsController < EndpointController
    include RelationshipReading

    def show = render_relationship(Document::Relationship)
  end
end
