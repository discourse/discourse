# frozen_string_literal: true

module DiscourseWorkflows
  module Actions
    module HttpRequest
      class V1 < Actions::Base
        TIMEOUT_SECONDS = 30
        MAX_RESPONSE_BODY_SIZE = 1.megabyte
        FILTERED_HEADER_PATTERNS = [/key/i, /secret/i, /token/i, /authorization/i, /password/i]

        def self.identifier
          "action:http_request"
        end

        def self.icon
          "globe"
        end

        def self.color_key
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

        attr_reader :logs

        def execute_single(context, item:, config:)
          method = (config["method"] || "GET").downcase.to_sym
          url = config["url"]
          raise "URL is required" if url.blank?

          uri = build_uri(url, config["query_params"])
          headers = build_headers(config["headers"])
          apply_authentication(config, headers)
          body = build_body(method, config["body"], headers)

          @logs ||= []
          @logs << "#{method.to_s.upcase} #{uri}"
          if headers.present?
            filtered = ActiveSupport::ParameterFilter.new(FILTERED_HEADER_PATTERNS).filter(headers)
            filtered.each { |k, v| @logs << "#{k}: #{v}" }
          end
          @logs << "[body omitted]" if body.present?

          conn =
            Faraday.new(nil, request: { timeout: TIMEOUT_SECONDS }) do |f|
              f.adapter FinalDestination::FaradayAdapter
            end

          response = conn.run_request(method, uri.to_s, body, headers)

          unless (200..299).cover?(response.status)
            raise "HTTP request failed with status #{response.status}"
          end

          {
            status: response.status,
            headers: response.headers.to_h,
            body: parse_response_body(response),
          }
        end

        private

        ALLOWED_PORTS = Set[80, 443].freeze

        def build_uri(url, query_params)
          uri = URI.parse(url)
          if %w[http https].exclude?(uri.scheme&.downcase)
            raise "Only HTTP and HTTPS URLs are supported"
          end
          raise "Only standard ports (80/443) are supported" if ALLOWED_PORTS.exclude?(uri.port)

          if query_params.is_a?(Array) && query_params.any?
            existing = URI.decode_www_form(uri.query || "")
            query_params.each { |qp| existing << [qp["key"], qp["value"]] if qp["key"].present? }
            uri.query = URI.encode_www_form(existing) if existing.any?
          end

          uri
        end

        def build_headers(headers_config)
          return {} unless headers_config.is_a?(Array)

          headers_config.each_with_object({}) do |h, headers|
            headers[h["key"]] = h["value"] if h["key"].present?
          end
        end

        def build_body(method, body_config, headers)
          return nil if %i[post put patch].exclude?(method) || body_config.blank?
          headers["Content-Type"] ||= "application/json"
          body_config
        end

        def apply_authentication(config, headers)
          auth_mode = config["authentication"] || "none"
          return if auth_mode == "none"

          credential_id = config["credential_id"]
          return if credential_id.blank?

          credential = DiscourseWorkflows::Credential.find_by(id: credential_id)
          return unless credential

          cred_data = credential.decrypted_data
          resolver = DiscourseWorkflows::ExpressionResolver.new({})

          case auth_mode
          when "basic_auth"
            user = resolver.resolve(cred_data["user"])
            password = resolver.resolve(cred_data["password"])
            headers["Authorization"] = "Basic #{Base64.strict_encode64("#{user}:#{password}")}"
          when "bearer_token"
            token = resolver.resolve(cred_data["token"])
            headers["Authorization"] = "Bearer #{token}"
          end
        end

        def parse_response_body(response)
          content_type = response.headers["content-type"] || ""
          body = response.body.to_s.truncate(MAX_RESPONSE_BODY_SIZE)

          if content_type.include?("application/json")
            JSON.parse(body)
          else
            { "data" => body }
          end
        rescue JSON::ParserError
          { "data" => body }
        end
      end
    end
  end
end
