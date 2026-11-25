# frozen_string_literal: true

module DiscourseMcp
  class Catalog
    def initialize(request_context:)
      @request_context = request_context
    end

    # The primitives this request can use: exposed by the admin, allowed by the
    # content policy and covered by the request's scopes.
    def list(kind)
      exposed(kind).select do |primitive|
        usable?(primitive) && request_context.has_scopes?(primitive.required_scopes)
      end
    end

    def find(kind, identifier)
      list(kind).find { |primitive| primitive.identifier == identifier.to_s }
    end

    # Ignores the content policy and scopes, so callers can tell a blocked
    # primitive apart from an unknown one.
    def find_exposed(kind, identifier)
      exposed(kind).find { |primitive| primitive.identifier == identifier.to_s }
    end

    def usable?(primitive)
      request_context.content_policy.allows_primitive?(primitive)
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
