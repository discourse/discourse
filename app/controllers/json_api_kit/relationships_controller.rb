# frozen_string_literal: true

module JsonApiKit
  class RelationshipsController < BaseController
    include RelationshipReading

    def show = render_relationship(Document::Relationship)
  end
end
