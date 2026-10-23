# frozen_string_literal: true

module JsonApiKit
  class RelatedResourcesController < EndpointController
    include RelationshipReading

    def index = render_relationship(Document::Collection)
  end
end
