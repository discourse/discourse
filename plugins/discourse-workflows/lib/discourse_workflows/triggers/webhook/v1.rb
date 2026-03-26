# frozen_string_literal: true

module DiscourseWorkflows
  module Triggers
    module Webhook
      class V1 < Triggers::Base
        def self.identifier
          "trigger:webhook"
        end

        def self.output_schema
          { body: :object, headers: :object, query: :object, method: :string, webhook_url: :string }
        end

        def self.configuration_schema
          {
            url_preview: {
              type: :custom,
              required: true,
              ui: {
                control: :url_preview,
              },
            },
            http_method: {
              type: :options,
              required: true,
              default: "GET",
              options: %w[GET POST PUT DELETE PATCH HEAD],
              expression: true,
            },
            path: {
              type: :string,
              required: true,
            },
            response_mode: {
              type: :options,
              required: true,
              default: "immediately",
              options: %w[immediately when_last_node_finishes respond_to_webhook],
            },
            response_code: {
              type: :string,
              required: false,
              default: "200",
              visible_if: {
                response_mode: %w[when_last_node_finishes],
              },
            },
          }
        end

        def initialize(body:, headers:, query:, method:, webhook_url:)
          @body = body
          @headers = headers
          @query = query
          @method = method
          @webhook_url = webhook_url
        end

        def output
          {
            body: @body,
            headers: @headers,
            query: @query,
            method: @method,
            webhook_url: @webhook_url,
          }
        end
      end
    end
  end
end
