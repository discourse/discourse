# frozen_string_literal: true

module JsonApiKit
  class RelatedResourcesController < BaseController
    include RelationshipReading

    def index = render_relationship(Document::Collection)
  end
end
