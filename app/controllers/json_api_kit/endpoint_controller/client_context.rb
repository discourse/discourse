# frozen_string_literal: true

module JsonApiKit
  class EndpointController
    module ClientContext
      ROOT = "/api"

      private

      def client = Client.new(guardian:, edition:, urls:)

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
