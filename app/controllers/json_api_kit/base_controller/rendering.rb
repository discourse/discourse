# frozen_string_literal: true

module JsonApiKit
  class BaseController
    module Rendering
      extend ActiveSupport::Concern

      included do
        before_action :set_json_format

        rescue_from(Discourse::InvalidAccess) do
          render_document(Document::Errors.new(Forbidden.new))
        end

        rescue_from(Request::Invalid) do |error|
          render_document(Document::Errors.new(*error.refusals))
        end

        rescue_from(Error) { |error| render_document(Document::Errors.new(error)) }
      end

      def rescue_with_handler(*)
        super || render_server_error(*)
      end

      private

      def set_json_format = request.format = :json

      def render_document(document, status: document.status)
        render json: document.to_h, status:, content_type: Pagination::Profile::MEDIA_TYPE
      end

      def render_resource(record, status: :ok)
        document =
          Document::Individual.from(
            record,
            resource: request_resource,
            input: request_query,
            client:,
          )
        response.location = document.location if Rack::Utils.status_code(status) == 201
        render_document(document, status:)
      end

      def render_validation_errors(errors)
        render_document(Document::Errors.new(*request_body.validation_errors(errors)))
      end

      def render_server_error(error)
        Discourse.warn_exception(error, message: "JSON:API request failed")
        render_document(Document::Errors.new(InternalServerError.new))
      end
    end
  end
end
