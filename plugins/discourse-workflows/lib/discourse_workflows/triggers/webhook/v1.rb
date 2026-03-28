# frozen_string_literal: true

module DiscourseWorkflows
  module Triggers
    module Webhook
      class V1 < Triggers::Base
        def self.identifier
          "trigger:webhook"
        end

        def self.icon
          "globe"
        end

        def self.color_key
          "purple"
        end

        def self.output_schema
          WebhookSchema::OUTPUT_FIELDS
        end

        def self.configuration_schema
          {
            url_preview: {
              type: :custom,
              required: false,
              ui: {
                control: :url_preview,
              },
            },
            **WebhookSchema::CONFIGURATION_FIELDS,
            path: {
              type: :string,
              required: true,
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
