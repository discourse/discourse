# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Webhook
      class V1 < NodeType
        description(
          name: "trigger:webhook",
          version: "1.0",
          defaults: {
            icon: "globe",
            color: "purple",
          },
          output_contracts: [{ schema: Schema::WEBHOOK_REQUEST_SCHEMA }],
          properties: {
            url_preview: {
              type: :custom,
              required: false,
              ui: {
                control: :url_preview,
              },
            },
            **Schemas::Webhook::CONFIGURATION_FIELDS,
            path: {
              type: :string,
              required: true,
            },
          },
          capabilities: {
            manually_triggerable: true,
          },
          credentials: Schemas::Webhook::CREDENTIALS,
          webhooks: [{ name: "default", path: "path", http_method: "http_method" }],
        )

        def initialize(body:, headers:, params: {}, query:, method:, webhook_url:, raw_body: nil)
          super(parameters: {})
          @body = body
          @headers = headers
          @params = params
          @query = query
          @method = method
          @webhook_url = webhook_url
          @raw_body = raw_body
        end

        def output
          data = {
            body: @body,
            headers: @headers,
            params: @params,
            query: @query,
            method: @method,
            webhook_url: @webhook_url,
          }
          data[:raw_body] = @raw_body if @raw_body.present?
          data
        end
      end
    end
  end
end
