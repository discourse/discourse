# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module RespondToWebhook
      class V1 < NodeType
        include Nodes::HttpHelpers

        DEFAULT_STATUS_CODES = { "redirect" => 302, "json" => 200, "text" => 200, "no_data" => 204 }

        def self.identifier
          "action:respond_to_webhook"
        end

        def self.icon
          "reply"
        end

        def self.color
          "purple"
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

        def execute(exec_ctx)
          items =
            exec_ctx.input_items.map do |item|
              config = exec_ctx.get_parameters(item)
              result = process(config)
              Item.new(result).to_h
            end
          ItemContract.validate_items!(items, source: self.class.identifier)
          [items]
        end

        private

        def process(config)
          response_type = config.fetch("response_type") { "json" }
          status_code = (config["status_code"].presence || DEFAULT_STATUS_CODES[response_type]).to_i
          status_code = DEFAULT_STATUS_CODES[response_type] if response_type == "redirect"

          {
            response_type: response_type,
            status_code: status_code,
            redirect_url: config["redirect_url"],
            response_body: config["response_body"],
            headers: normalize_headers(config["headers"]),
          }
        end
      end
    end
  end
end
