# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module HttpRequest
      class V1 < NodeType
        include HttpHelpers

        description(
          name: "action:http_request",
          version: "1.0",
          defaults: {
            icon: "globe",
            color: "indigo",
          },
          capabilities: {
            run_scope: "per_item",
          },
          properties: {
            method: {
              type: :options,
              required: true,
              options: %w[GET POST PUT DELETE PATCH],
              default: "GET",
              ui: {
                expression: true,
              },
            },
            url: {
              type: :string,
              required: true,
            },
            authentication: {
              type: :options,
              options: %w[none basic_auth bearer_token header_auth],
              default: "none",
              no_data_expression: true,
            },
            headers: {
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
            query_params: {
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
            content_type: {
              type: :options,
              required: false,
              options: %w[json form_urlencoded raw],
              default: "json",
              display_options: {
                show: {
                  method: %w[POST PUT PATCH],
                },
              },
            },
            body_json: {
              type: :string,
              required: false,
              display_options: {
                show: {
                  method: %w[POST PUT PATCH],
                  content_type: ["json"],
                },
              },
              ui: {
                control: :textarea,
              },
            },
            body_raw: {
              type: :string,
              required: false,
              display_options: {
                show: {
                  method: %w[POST PUT PATCH],
                  content_type: ["raw"],
                },
              },
              ui: {
                control: :textarea,
              },
            },
            body_form: {
              type: :fixed_collection,
              required: false,
              display_options: {
                show: {
                  method: %w[POST PUT PATCH],
                  content_type: ["form_urlencoded"],
                },
              },
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
            raw_content_type: {
              type: :string,
              required: false,
              default: "text/plain",
              display_options: {
                show: {
                  method: %w[POST PUT PATCH],
                  content_type: ["raw"],
                },
              },
            },
            never_error: {
              type: :boolean,
              required: false,
              default: false,
            },
            full_response: {
              type: :boolean,
              required: false,
              default: false,
            },
            max_response_size_kb: {
              type: :integer,
              required: false,
              default: 1024,
            },
          },
          credentials: [
            {
              name: "auth",
              credential_types: %w[basic_auth bearer_token header_auth],
              required: false,
              display_options: {
                show: {
                  authentication: %w[basic_auth bearer_token header_auth],
                },
              },
              label_key: "discourse_workflows.http_request.credential",
            },
          ],
        )

        def execute(exec_ctx)
          items =
            exec_ctx.input_items.flat_map.with_index do |item, item_index|
              config = {
                "method" => exec_ctx.get_node_parameter("method", item_index, default: "GET"),
                "url" => exec_ctx.get_node_parameter("url", item_index),
                "authentication" =>
                  exec_ctx.get_node_parameter("authentication", item_index, default: "none"),
                "content_type" =>
                  exec_ctx.get_node_parameter("content_type", item_index, default: "json"),
                "body_json" => exec_ctx.get_node_parameter("body_json", item_index),
                "body_raw" => exec_ctx.get_node_parameter("body_raw", item_index),
                "raw_content_type" =>
                  exec_ctx.get_node_parameter(
                    "raw_content_type",
                    item_index,
                    default: "text/plain",
                  ),
                "never_error" =>
                  exec_ctx.get_node_parameter("never_error", item_index, default: false),
                "full_response" =>
                  exec_ctx.get_node_parameter("full_response", item_index, default: false),
                "max_response_size_kb" =>
                  exec_ctx.get_node_parameter("max_response_size_kb", item_index, default: 1024),
              }
              result = process(config, item_index, exec_ctx)
              wrap_result(result, paired_item: exec_ctx.paired_item_for(item))
            end
          [items]
        end

        private

        def process(config, item_index, exec_ctx)
          method = config.fetch("method") { "GET" }.downcase.to_sym
          headers =
            normalize_headers(
              exec_ctx.get_node_parameter("headers.values", item_index, default: []),
            )
          body =
            build_body(
              method,
              config,
              headers,
              form_params: exec_ctx.get_node_parameter("body_form.values", item_index, default: []),
            )
          query_params = exec_ctx.get_node_parameter("query_params.values", item_index, default: [])
          response =
            exec_ctx.http_request(
              method: method,
              url: config["url"],
              headers: headers,
              body: body,
              item_index: item_index,
              options: request_options(config, query_params),
            )
          if full_response?(config)
            {
              body: response.body,
              headers: response.headers,
              status_code: response.status,
              status_message: response.status_message,
            }
          else
            response.body
          end
        end

        def full_response?(config)
          config["full_response"] == true
        end

        def wrap_result(result, paired_item:)
          if result.is_a?(Array)
            result.map { |entry| wrap_response_body(entry, paired_item:) }
          else
            [wrap_response_body(result, paired_item:)]
          end
        end

        def wrap_response_body(body, paired_item:)
          wrap(body.is_a?(Hash) ? body : { data: body }, paired_item:)
        end

        def request_options(config, query_params)
          config.slice("authentication", "never_error", "max_response_size_kb").merge(
            "query_params" => query_params,
          )
        end
      end
    end
  end
end
