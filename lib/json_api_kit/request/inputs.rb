# frozen_string_literal: true

module JsonApiKit
  class Request
    class Inputs
      def initialize(query:, body:, resource:)
        @resource = resource
        @raw_body = body
        @query = verify(Input::Individual.new(query, resource:, edition: resource.edition))
      end

      attr_reader :query

      def body = @body ||= verify(Body.parse(raw_body, resource:))

      private

      attr_reader :resource, :raw_body

      def verify(input)
        raise Invalid.new(input.refusals) if input.invalid?
        input
      end
    end
  end
end
