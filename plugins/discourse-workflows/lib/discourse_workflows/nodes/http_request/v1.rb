# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module HttpRequest
      class V1 < NodeType
        TIMEOUT_SECONDS = 30
        FILTERED_HEADER_PATTERNS = [/key/i, /secret/i, /token/i, /authorization/i, /password/i]

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
          }
        end

        def self.output_schema
          { status: :integer, headers: :object, body: :object }
        end

        def execute(exec_ctx)
          items =
            exec_ctx.input_items.map do |item|
              config = exec_ctx.get_parameters(item)
              result = process(config, exec_ctx.log)
              wrap(result)
            end
          [items]
        end

        private

        def process(config, log)
          method, uri, headers, body = RequestBuilder.new(config).build
          log_request(log, method, uri, headers, body)
          never_error = config.fetch("never_error", false)
          response = send_request(method, uri, headers, body, never_error:)
          ResponseParser.parse(response)
        end

        def log_request(log, method, uri, headers, body)
          log.info("#{method.to_s.upcase} #{uri}")
          if headers.present?
            filtered = ActiveSupport::ParameterFilter.new(FILTERED_HEADER_PATTERNS).filter(headers)
            filtered.each { |k, v| log.info("#{k}: #{v}") }
          end
          log.info("[body omitted]") if body.present?
        end

        def send_request(method, uri, headers, body, never_error: false)
          conn =
            Faraday.new(
              nil,
              request: {
                timeout: TIMEOUT_SECONDS,
                open_timeout: TIMEOUT_SECONDS,
                write_timeout: TIMEOUT_SECONDS,
              },
            ) { |f| f.adapter FinalDestination::FaradayAdapter }
          response = conn.run_request(method, uri.to_s, body, headers)
          if !never_error && !(200..299).cover?(response.status)
            raise "HTTP request failed with status #{response.status}"
          end
          response
        end
      end
    end
  end
end
