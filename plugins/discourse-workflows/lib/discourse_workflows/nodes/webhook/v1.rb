# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Webhook
      class V1 < NodeType
        def self.identifier
          "trigger:webhook"
        end

        def self.icon
          "globe"
        end

        def self.color_key
          "purple"
        end

        def self.manually_triggerable?
          true
        end

        def self.output_schema
          Schemas::Webhook::OUTPUT_FIELDS
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
            **Schemas::Webhook::CONFIGURATION_FIELDS,
            path: {
              type: :string,
              required: true,
            },
          }
        end

        def initialize(body:, headers:, query:, method:, webhook_url:)
          super(configuration: {})
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
