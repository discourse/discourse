# frozen_string_literal: true

module JsonApiKit
  class RelatedResourcesController < EndpointController
    include RelationshipReading

    def index = render_related_resources

    def show = render_related_resources
  end
end
