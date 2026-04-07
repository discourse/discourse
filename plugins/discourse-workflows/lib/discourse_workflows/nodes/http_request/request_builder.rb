# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module HttpRequest
      class RequestBuilder
        include HttpHelpers

        ALLOWED_PORTS = Set[80, 443].freeze

        def initialize(config)
          @config = config
        end

        def build
          method = @config.fetch("method") { "GET" }.downcase.to_sym
          raise "URL is required" if @config["url"].blank?

          uri = build_uri(@config["url"], @config["query_params"])
          headers = normalize_headers(@config["headers"])
          Authenticator.apply(@config, headers)
          body = build_body(method, @config["body"], headers)
          [method, uri, headers, body]
        end

        private

        def build_uri(url, query_params)
          uri = URI.parse(url)
          if %w[http https].exclude?(uri.scheme&.downcase)
            raise "Only HTTP and HTTPS URLs are supported"
          end
          raise "Only standard ports (80/443) are supported" if ALLOWED_PORTS.exclude?(uri.port)

          append_query_params(uri, query_params)
          uri
        end

        def append_query_params(uri, query_params)
          return unless query_params.is_a?(Array) && query_params.any?

          existing = URI.decode_www_form(uri.query || "")
          query_params.each { |qp| existing << [qp["key"], qp["value"]] if qp["key"].present? }
          uri.query = URI.encode_www_form(existing) if existing.any?
        end

        def build_body(method, body_config, headers)
          return nil if %i[post put patch].exclude?(method) || body_config.blank?
          headers["Content-Type"] ||= "application/json"
          body_config
        end
      end
    end
  end
end
