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
      end

      def rescue_with_handler(*)
        super || render_server_error(*)
      end

      private

      def set_json_format = request.format = :json

      def render_document(document)
        render json: document.to_h,
               status: document.status,
               content_type: Pagination::Profile::MEDIA_TYPE
      end

      def render_server_error(error)
        Discourse.warn_exception(error, message: "JSON:API request failed")
        render_document(Document::Errors.new(InternalServerError.new))
      end
    end
  end
end
