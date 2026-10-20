# frozen_string_literal: true

module JsonApiKit
  class Request
    class Inputs
      delegate :query_parameters,
               :raw_post,
               :request_method,
               :path_parameters,
               to: :request,
               private: true

      def initialize(request, resource:)
        @request = request
        @resource = resource
        @query =
          verify(Input::Individual.new(query_parameters, resource:, edition: resource.edition))
      end

      attr_reader :query

      def body = @body ||= verify(parse_body)

      private

      attr_reader :request, :resource

      def id = path_parameters[:id]

      def parse_body
        case request_method
        when "PATCH"
          Body::Update.parse(raw_post, resource:, id:)
        else
          Body.parse(raw_post, resource:)
        end
      end

      def verify(input)
        raise Invalid.new(input.refusals) if input.invalid?
        input
      end
    end
  end
end
