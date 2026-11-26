# frozen_string_literal: true

module JsonApiKit
  class RelationshipsController
    module RequestInput
      extend ActiveSupport::Concern

      included do
        rescue_from(ActiveRecord::RecordInvalid) do |error|
          render_validation_errors(error.record.errors)
        end
      end

      delegate :query, :body, to: :request_inputs, prefix: :request, private: true

      private

      def service_params = { params: request_body.parameters.merge(route_parameters), guardian: }

      def route_parameters
        request.path_parameters.except(:controller, :action, :format, :relationship)
      end

      def render_linkage_of(records, **options)
        render_document(
          relationship.linkage_document.from(
            records,
            resource: relationship.resource,
            input: request_query,
            client:,
          ),
          **options,
        )
      end

      def render_validation_errors(errors)
        render_document(Document::Errors.new(*request_body.validation_errors(errors)))
      end

      def render_service_failure(result)
        Rails.logger.warn("JSON:API request failed\n#{result.inspect_steps}")
        render_document(Document::Errors.new(InternalServerError.new))
      end

      def request_inputs
        @request_inputs ||=
          Request::LinkageInputs.new(request, resource: owner_resource, relationship_name:)
      end
    end
  end
end
