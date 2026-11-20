# frozen_string_literal: true

module DiscourseMcp
  class Catalog
    def initialize(request_context:)
      @request_context = request_context
    end

    def list(kind)
      exposed(kind).select { |primitive| request_context.has_scopes?(primitive.required_scopes) }
    end

    def find(kind, identifier)
      list(kind).find { |primitive| primitive.identifier == identifier.to_s }
    end

    def find_exposed(kind, identifier)
      exposed(kind).find { |primitive| primitive.identifier == identifier.to_s }
    end

    private

    attr_reader :request_context

    def exposed(kind)
      policies = McpPrimitive.exposed.where(kind: kind.to_s).pluck(:identifier).to_set

      DiscourseMcp
        .registry
        .all(kind)
        .select { |primitive| policies.include?(primitive.identifier) && primitive.available? }
    end
  end
end
