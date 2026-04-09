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

        def self.configuration_schema
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
            body: {
              type: :string,
              required: false,
              visible_if: {
                method: %w[POST PUT PATCH],
              },
              ui: {
                control: :textarea,
                rows: 6,
              },
            },
          }
        end

        def self.output_schema
          { status: :integer, headers: :object, body: :object }
        end

        attr_reader :log

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
          method, uri, headers, body = RequestBuilder.new(config).build
          log_request(method, uri, headers, body)
          response = send_request(method, uri, headers, body)
          ResponseParser.parse(response)
        end

        def log_request(method, uri, headers, body)
          @log ||= StepLog.new
          @log.info("#{method.to_s.upcase} #{uri}")
          if headers.present?
            filtered = ActiveSupport::ParameterFilter.new(FILTERED_HEADER_PATTERNS).filter(headers)
            filtered.each { |k, v| @log.info("#{k}: #{v}") }
          end
          @log.info("[body omitted]") if body.present?
        end

        def send_request(method, uri, headers, body)
          conn =
            Faraday.new(nil, request: { timeout: TIMEOUT_SECONDS }) do |f|
              f.adapter FinalDestination::FaradayAdapter
            end
          response = conn.run_request(method, uri.to_s, body, headers)
          unless (200..299).cover?(response.status)
            raise "HTTP request failed with status #{response.status}"
          end
          response
        end
      end
    end
  end
end
