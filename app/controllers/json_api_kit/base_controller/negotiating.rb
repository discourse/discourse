# frozen_string_literal: true

module JsonApiKit
  class BaseController
    module Negotiating
      extend ActiveSupport::Concern

      OTHER_PARAMETER = "Content-Type accepts the ext and profile parameters only."
      NO_EXTENSION = "This API applies no extension."
      UNREADABLE_ACCEPT =
        "Accept must allow #{MediaType::JSON_API} with the ext and profile parameters only."

      included do
        before_action :set_vary_header
        before_action :negotiate
      end

      private

      def set_vary_header = response.headers["Vary"] ||= "Accept"

      def negotiate
        (content_type_refusal || accept_refusal).try { render_document(Document::Errors.new(it)) }
      end

      def content_type_refusal
        return unless request_media_type&.json_api?
        return UnsupportedMediaType.new(OTHER_PARAMETER) if request_media_type.modified?
        UnsupportedMediaType.new(NO_EXTENSION) if request_media_type.extended?
      end

      def accept_refusal
        return if accepted_media_types.empty? || accepted_media_types.any? { !it.modified? }
        NotAcceptable.new(UNREADABLE_ACCEPT)
      end

      def request_media_type
        @request_media_type ||= MediaType.parse(request.headers["Content-Type"]).first
      end

      def accepted_media_types
        @accepted_media_types ||= MediaType.parse(request.headers["Accept"]).select(&:json_api?)
      end
    end
  end
end
