# frozen_string_literal: true

module JsonApiKit
  class Request
    class LinkageInputs < Inputs
      def initialize(request, resource:, relationship_name:)
        @relationship_name = relationship_name
        super(request, resource:)
      end

      private

      attr_reader :relationship_name

      delegate :edition, :guardian, to: :resource, private: true
      delegate :glossary, to: :edition, private: true

      def verify_request
        unless relationship.writable?
          raise Forbidden.new("#{member_name} is not a writable relationship.")
        end
        return if relationship.writable_with?(request_method)
        raise Forbidden.new("#{member_name} cannot be updated with #{request_method}.")
      end

      def parse_query = Input::Empty.new(query_parameters, resource: related_resource, edition:)

      def parse_body = Body::Linkage.parse(raw_post, relationship:, resource:)

      def relationship
        @relationship ||=
          resource
            .relationships
            .fetch(relationship_name) { raise NotFound.new }
            .tap { raise NotFound.new unless it.readable_by?(guardian) }
      end

      def related_resource = @related_resource ||= resource.resource_for(relationship.resource)

      def member_name
        glossary.member_relationship(declared: relationship.name, type: resource.type)
      end
    end
  end
end
