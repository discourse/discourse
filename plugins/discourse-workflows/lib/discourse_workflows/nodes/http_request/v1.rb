# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module HttpRequest
      class V1 < NodeType
        include HttpHelpers

        def self.identifier
          "action:http_request"
        end

        def self.icon
          "globe"
        end

        def self.color
          "indigo"
        end

        def self.property_schema
          {
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
              options: %w[none basic_auth bearer_token],
              default: "none",
              ui: {
                expression: true,
              },
            },
            credential_id: {
              type: :credential,
              visible_if: {
                authentication: %w[basic_auth bearer_token],
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
            query_params: {
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
            content_type: {
              type: :options,
              required: false,
              options: %w[json form_urlencoded raw],
              default: "json",
              visible_if: {
                method: %w[POST PUT PATCH],
              },
            },
            body_json: {
              type: :string,
              required: false,
              visible_if: {
                method: %w[POST PUT PATCH],
                content_type: "json",
              },
              ui: {
                control: :textarea,
              },
            },
            body_raw: {
              type: :string,
              required: false,
              visible_if: {
                method: %w[POST PUT PATCH],
                content_type: "raw",
              },
              ui: {
                control: :textarea,
              },
            },
            body_form: {
              type: :collection,
              required: false,
              visible_if: {
                method: %w[POST PUT PATCH],
                content_type: "form_urlencoded",
              },
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
            raw_content_type: {
              type: :string,
              required: false,
              default: "text/plain",
              visible_if: {
                method: %w[POST PUT PATCH],
                content_type: "raw",
              },
            },
            never_error: {
              type: :boolean,
              required: false,
              default: false,
            },
            max_response_size_kb: {
              type: :integer,
              required: false,
              default: 1024,
            },
          }
        end

        def self.output_schema
          { status: :integer, headers: :object, body: :object }
        end

        def execute(exec_ctx)
          items =
            exec_ctx.input_items.map do |item|
              exec_ctx.with_item(item) do
                config = exec_ctx.get_parameters(item)
                result = process(config, exec_ctx)
                wrap(result)
              end
            end
          [items]
        end

        private

        def process(config, exec_ctx)
          method = config.fetch("method") { "GET" }.downcase.to_sym
          headers = normalize_headers(config["headers"])
          body = build_body(method, config, headers)
          log_request(exec_ctx.log, method, config["url"], headers, body)
          response =
            exec_ctx.http_request(
              method: method,
              url: config["url"],
              headers: headers,
              body: body,
              options: request_options(config),
            )
          { status: response.status, headers: response.headers, body: response.body }
        end

        def log_request(log, method, uri, headers, body)
          log.info("#{method.to_s.upcase} #{uri}")
          if headers.present?
            filtered =
              ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters).filter(
                headers,
              )
            filtered.each { |k, v| log.info("#{k}: #{v}") }
          end
          if body.is_a?(Hash)
            filtered_body =
              ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters).filter(
                body,
              )
            log.info(filtered_body.to_json)
          elsif body.present?
            log.info("[body omitted]")
          end
        end

        def request_options(config)
          config.slice(
            "authentication",
            "credential_id",
            "never_error",
            "query_params",
            "max_response_size_kb",
          )
        end
      end
    end
  end
end
