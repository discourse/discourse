# frozen_string_literal: true

module DiscourseWorkflows
  module Actions
    module RespondToWebhook
      class V1 < Actions::Base
        DEFAULT_STATUS_CODES = { "redirect" => 302, "json" => 200, "text" => 200, "no_data" => 204 }

        def self.identifier
          "action:respond_to_webhook"
        end

        def self.metadata
          { icon: "reply" }
        end

        def self.configuration_schema
          {
            response_type: {
              type: :options,
              required: true,
              default: "json",
              options: %w[json redirect text no_data],
            },
            status_code: {
              type: :string,
              required: false,
              default: "200",
              visible_if: {
                response_type: %w[json text no_data],
              },
            },
            redirect_url: {
              type: :string,
              required: true,
              visible_if: {
                response_type: %w[redirect],
              },
            },
            response_body: {
              type: :string,
              required: false,
              visible_if: {
                response_type: %w[json text],
              },
              ui: {
                control: :textarea,
                rows: 6,
              },
            },
            headers: {
              type: :collection,
              item_schema: {
                key: {
                  type: :string,
                  required: true,
                },
                value: {
                  type: :string,
                  required: true,
                },
              },
            },
          }
        end

        def self.output_schema
          {
            response_type: :string,
            status_code: :integer,
            redirect_url: :string,
            response_body: :string,
            headers: :object,
          }
        end

        def execute_single(context, item:, config:)
          response_type = config["response_type"] || "json"
          status_code = (config["status_code"].presence || DEFAULT_STATUS_CODES[response_type]).to_i
          status_code = DEFAULT_STATUS_CODES[response_type] if response_type == "redirect"

          {
            response_type: response_type,
            status_code: status_code,
            redirect_url: config["redirect_url"],
            response_body: config["response_body"],
            headers: build_headers(config["headers"]),
          }
        end

        private

        def build_headers(headers_config)
          return {} unless headers_config.is_a?(Array)

          headers_config.each_with_object({}) do |h, headers|
            headers[h["key"]] = h["value"] if h["key"].present?
          end
        end
      end
    end
  end
end
