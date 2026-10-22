# frozen_string_literal: true

module JsonApiKit
  class Relationship
    def initialize(owner_id, name, resource:)
      @owner_id = owner_id
      @name = name
      @owner_resource = resource
    end

    delegate :resource, to: :declaration

    def scope = owner_resource.related_scope(declaration.name, owner_id:)

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
