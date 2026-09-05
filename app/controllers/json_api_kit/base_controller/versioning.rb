# frozen_string_literal: true

module JsonApiKit
  class BaseController
    module Versioning
      extend ActiveSupport::Concern

      included { before_action :resolve_version }

      private

      def resolve_version
        response.headers[ApiVersion::HEADER] = Timeline.resolve(requested_version).to_s
      rescue Error => error
        render_document(Document::Errors.new(error))
      end

      def requested_version = request.headers[ApiVersion::HEADER]
    end
  end
end
