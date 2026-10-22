# frozen_string_literal: true

module JsonApiKit
  class Relationship
    def initialize(id, name, resource:, client:)
      @id = id
      @name = name.tr("-", "_")
      @owner_resource = resource.new(guardian: client.guardian, edition: client.edition)
    end

    delegate :resource, to: :declaration

    def scope
      owner_resource.schema.association(declaration.name.to_sym, [owner]).related_scope
    end

    private

    attr_reader :id, :name, :owner_resource

    delegate :guardian, to: :owner_resource, private: true

    def owner = @owner ||= owner_resource.find(id).record.record

    def declaration
      @declaration ||=
        owner_resource
          .relationships
          .fetch(name) { raise NotFound.new }
          .tap { |relationship| raise NotFound.new unless relationship.readable_by?(guardian) }
    end
  end
end
