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

      def render_document(value, **options)
        document =
          Document.from(value) { { resource: request_resource, input: request_query, client: } }
        options = { status: document.status, content_type: Pagination::Profile::MEDIA_TYPE }.merge(
          options,
        )
        response.headers.merge!(document.headers(status: options.fetch(:status)))
        render json: document.to_h, **options
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
