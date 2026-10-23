# frozen_string_literal: true

module JsonApiKit
  class Relationship
    def initialize(owner_id, name, resource:)
      @owner_id = owner_id
      @name = name
      @owner_resource = resource
    end

    def resource
      @resource ||= declaration.resource.new(guardian:, edition: owner_resource.edition)
    end

    def scope
      resource.related_records(
        declaration,
        owners: [owner_resource.record_for(owner_id)],
        owner_resource:,
      ).scope
    end

    private

    attr_reader :owner_id, :name, :owner_resource

    delegate :guardian, to: :owner_resource, private: true

    def declaration
      @declaration ||=
        owner_resource
          .relationships
          .fetch(name) { raise NotFound.new }
          .tap { |relationship| raise NotFound.new unless relationship.readable_by?(guardian) }
    end
  end
end
