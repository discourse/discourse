# frozen_string_literal: true

module JsonApiKit
  class BaseController
    module Versioning
      extend ActiveSupport::Concern

      included { before_action :resolve_version }

      private

      def resolve_version
        response.headers[ApiVersion::HEADER] = version.to_s
      rescue Error => error
        render_document(Document::Errors.new(error))
      end

      def version = @version ||= Timeline.resolve(requested_version)

      def requested_version = request.headers[ApiVersion::HEADER]

      def glossary = @glossary ||= Glossary.resource(version)
    end
  end
end
