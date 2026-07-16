# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module RespondToWebhook
      class V1 < NodeType
        include Nodes::HttpHelpers

        DEFAULT_STATUS_CODES = {
          "redirect" => 302,
          "json" => 200,
          "text" => 200,
          "no_data" => 204,
          "first_incoming_item" => 200,
          "all_incoming_items" => 200,
        }

        description(
          name: "action:respond_to_webhook",
          version: "1.0",
          defaults: {
            icon: "reply",
            color: "purple",
          },
          output_contracts: [{ mode: :passthrough }],
          properties: {
            response_type: {
              type: :options,
              required: true,
              default: "json",
              options: %w[json redirect text no_data first_incoming_item all_incoming_items],
            },
            status_code: {
              type: :string,
              required: false,
              default: "200",
              display_options: {
                show: {
                  response_type: %w[json text no_data first_incoming_item all_incoming_items],
                },
              },
            },
            redirect_url: {
              type: :string,
              required: true,
              display_options: {
                show: {
                  response_type: %w[redirect],
                },
              },
            },
            allowed_redirect_domains: {
              type: :fixed_collection,
              display_options: {
                show: {
                  response_type: %w[redirect],
                },
              },
              type_options: {
                multiple_values: true,
              },
              options: [{ name: "values", values: { domain: { type: :string, required: true } } }],
            },
            response_body: {
              type: :string,
              required: false,
              display_options: {
                show: {
                  response_type: %w[json text],
                },
              },
              ui: {
                control: :textarea,
              },
            },
            response_key: {
              type: :string,
              required: false,
              display_options: {
                show: {
                  response_type: %w[first_incoming_item all_incoming_items],
                },
              },
            },
            response_headers: {
              type: :fixed_collection,
              type_options: {
                multiple_values: true,
              },
              options: [
                {
                  name: "values",
                  values: {
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
              ],
            },
          },
        )

        def execute(exec_ctx)
          raise_node_error!("No webhook response context available") unless exec_ctx.webhook_ctx

          exec_ctx.webhook_ctx.respond(build_response(exec_ctx))
          [exec_ctx.input_items]
        end

        private

        def build_response(exec_ctx)
          item_index = 0
          config = {
            "response_type" =>
              exec_ctx.get_node_parameter("response_type", item_index, default: "json"),
            "status_code" => exec_ctx.get_node_parameter("status_code", item_index),
            "redirect_url" => exec_ctx.get_node_parameter("redirect_url", item_index),
            "response_body" => exec_ctx.get_node_parameter("response_body", item_index),
            "response_key" => exec_ctx.get_node_parameter("response_key", item_index),
          }

          response_type = config.fetch("response_type") { "json" }
          status_code = (config["status_code"].presence || DEFAULT_STATUS_CODES[response_type]).to_i
          status_code = DEFAULT_STATUS_CODES[response_type] if response_type == "redirect"
          headers =
            normalize_headers(
              exec_ctx.get_node_parameter("response_headers.values", item_index, default: []),
            )

          body =
            case response_type
            when "redirect"
              redirect_url = config["redirect_url"]
              allowed_redirect_domains =
                normalize_allowed_redirect_domains(
                  exec_ctx.get_node_parameter(
                    "allowed_redirect_domains.values",
                    item_index,
                    default: [],
                  ),
                )
              unless RedirectUrlValidator.valid?(redirect_url, allowed_redirect_domains)
                return(
                  WebhookResponse.new(body: { error: "invalid_redirect_url" }, status_code: 400)
                )
              end
              headers["Location"] = redirect_url
              nil
            when "json"
              parse_json_body(config["response_body"])
            when "text"
              headers["Content-Type"] ||= "text/plain; charset=utf-8"
              config["response_body"].to_s
            when "no_data"
              nil
            when "all_incoming_items"
              maybe_wrap_response_key(
                config["response_key"],
                exec_ctx.input_items.map { |item| item["json"] || {} },
              )
            when "first_incoming_item"
              maybe_wrap_response_key(
                config["response_key"],
                exec_ctx.input_items.dig(0, "json") || {},
              )
            end

          WebhookResponse.new(
            body: body,
            headers: headers,
            no_body: response_type == "no_data",
            status_code: status_code,
          )
        end

        def normalize_allowed_redirect_domains(domain_rows)
          domain_rows.filter_map do |domain_config|
            domain_config["domain"].to_s.strip.downcase.presence
          end
        end

        def parse_json_body(body)
          return body unless body.is_a?(String)

          JSON.parse(body)
        rescue JSON::ParserError
          raise_node_error!("Invalid JSON in response_body")
        end

        def maybe_wrap_response_key(response_key, body)
          response_key.present? ? { response_key => body } : body
        end
      end
    end
  end
end
