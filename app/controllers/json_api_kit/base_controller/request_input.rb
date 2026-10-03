# frozen_string_literal: true

module JsonApiKit
  class BaseController
    module RequestInput
      extend ActiveSupport::Concern

      private

      def request_body
        @request_body ||=
          begin
            verify_input(request_query)
            verify_input(Request::Body.parse(request.raw_post, resource: request_resource))
          end
      end

      def request_query
        @request_query ||=
          Request::Input::Individual.new(
            request.query_parameters,
            resource: request_resource,
            edition:,
          )
      end

      def request_resource = @request_resource ||= resource.new(guardian:, edition:)

      def verify_input(input)
        raise Request::Invalid.new(input.refusals) if input.invalid?
        input
      end
    end
  end
end
