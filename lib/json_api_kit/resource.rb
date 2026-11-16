# frozen_string_literal: true

module JsonApiKit
  class Resource
    UnreadableAttribute = Class.new(StandardError)
    UnknownRelationship = Class.new(KeyError)

    include Adapting
    include Naming
    include Sorting
    include Filtering
    include Paging
    include Anchoring
    include Fields
    include Including
    include QueryInterface

    def initialize(guardian:, edition: Edition.current, resources: {})
      @guardian = guardian
      @edition = edition
      @resources = resources
      @resources[self.class] = self
    end

    attr_reader :guardian, :edition

    def resource_for(resource_class)
      resources[resource_class] ||= resource_class.new(guardian:, edition:, resources:)
    end

    def related_resource(name) = resource_for(self.class.related_resource(name))

    private

    attr_reader :resources
  end
end
