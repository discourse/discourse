# frozen_string_literal: true

module JsonApiKit
  class BaseController
    module Fetching
      extend ActiveSupport::Concern

      def index
        render_document(Document::Collection.for(request.query_parameters, resource:, client:))
      end

      def show
        render_document(
          Document::Individual.for(params[:id], request.query_parameters, resource:, client:),
        )
      end
    end
  end
end
