# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module HttpRequest
      class RequestBuilder
        include HttpHelpers
        include NodeErrorHandling

        def initialize(config, exec_ctx = nil, item_index = 0)
          @config = config
          @exec_ctx = exec_ctx
          @item_index = item_index
        end

        def build
          method = @config.fetch("method") { "GET" }.downcase.to_sym
          if @config["url"].blank?
            raise_node_error!(I18n.t("discourse_workflows.errors.http_request.url_required"))
          end

          uri = build_uri(@config["url"], @config["query_params"])
          headers = (@config["headers"] || {}).to_h.compact
          secret_headers = Authenticator.apply(@config, headers, @exec_ctx, item_index: @item_index)
          body = @config.key?("body") ? @config["body"] : build_body(method, @config, headers)
          log_request(method, uri, headers, body, secret_headers)
          [method, uri, headers, body]
        end

        private

        def log_request(method, uri, headers, body, secret_headers)
          log = @exec_ctx&.log
          return if log.nil?

          log.info("#{method.to_s.upcase} #{filtered_url_for_logging(uri.to_s)}")
          if headers.present?
            redact_headers(headers, secret_headers).each { |k, v| log.info("#{k}: #{v}") }
          end
          log.info("[body omitted]") if body.present?
        end

        def redact_headers(headers, secret_headers)
          ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters).filter(
            headers.merge(secret_headers.index_with { FILTERED_QUERY_VALUE }),
          )
        end

        def build_uri(url, query_params)
          uri = URI.parse(url)
          if %w[http https].exclude?(uri.scheme&.downcase)
            raise_node_error!(I18n.t("discourse_workflows.errors.http_request.unsupported_scheme"))
          end
          if uri.host.blank?
            raise_node_error!(I18n.t("discourse_workflows.errors.http_request.host_required"))
          end

          append_query_params(uri, query_params)
          uri
        rescue URI::InvalidURIError => e
          raise_node_error!("Invalid URL", description: e.message)
        end

        def append_query_params(uri, query_params)
          return if query_params.blank?

          existing = URI.decode_www_form(uri.query || "")
          query_params.each { |qp| existing << [qp["key"], qp["value"]] if qp["key"].present? }
          uri.query = URI.encode_www_form(existing) if existing.any?
        end
      end
    end
  end
end
