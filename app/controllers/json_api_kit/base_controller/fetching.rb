# frozen_string_literal: true

module JsonApiKit
  class BaseController
    module Fetching
      extend ActiveSupport::Concern

      ROOT = "/api"

      def index
        render_document(Document::Collection.for(request.query_parameters, resource:, client:))
      end

      def show
        render_document(
          Document::Individual.for(params[:id], request.query_parameters, resource:, client:),
        )
      end

      private

      def client = Client.new(guardian:, glossary:, urls:)

      def urls
        Urls.new(
          base: "#{request.base_url}#{ROOT}",
          current: "#{request.base_url}#{request.path}",
          parameters: request.query_parameters,
        )
      end
    end
  end
end
