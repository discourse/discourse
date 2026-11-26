# frozen_string_literal: true

module JsonApiKit
  class RelationshipsController < EndpointController
    include RelationshipReading
    include RequestInput

    def show = render_linkage
  end
end
