# frozen_string_literal: true

module JsonApiKit
  class BaseController
    module RequestInput
      extend ActiveSupport::Concern

      delegate :query, :body, to: :request_inputs, prefix: :request, private: true

      private

      def service_params = { params: request_body.parameters, guardian: }

      def render_document(value, **options)
        super(
          Document.from(value) { { resource: request_resource, input: request_query, client: } },
          **options,
        )
      end

      def render_validation_errors(errors)
        render_document(Document::Errors.new(*request_body.validation_errors(errors)))
      end

      def request_inputs
        @request_inputs ||=
          Request::Inputs.new(
            query: request.query_parameters,
            body: request.raw_post,
            resource: request_resource,
          )
      end

      def request_resource = @request_resource ||= resource.new(guardian:, edition:)
    end
  end
end
