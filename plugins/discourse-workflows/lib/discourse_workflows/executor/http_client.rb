# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    class HttpClient
      include Nodes::HttpHelpers
      include NodeErrorHandling

      Response = Struct.new(:status, :headers, :body, :status_message, keyword_init: true)

      TIMEOUT_SECONDS = 30
      DEFAULT_MAX_RETRIES = 0
      DEFAULT_RETRY_STATUSES = Set[429, 500, 502, 503, 504].freeze
      ERROR_BODY_MAX_BYTES = 10.kilobytes
      PACK_FORBIDDEN_HEADERS = /\A(?:cookie|host|content-length|proxy-)/i

      def initialize(exec_ctx, item_index = 0)
        @exec_ctx = exec_ctx
        @item_index = item_index
      end

      def request(method:, url:, headers: {}, body: nil, options: {})
        config = build_config(method, url, headers, body, options)
        request_method, uri, request_headers, request_body =
          DiscourseWorkflows::Nodes::HttpRequest::RequestBuilder.new(
            config,
            @exec_ctx,
            @item_index,
          ).build
        never_error = config.fetch("never_error", false)
        ensure_approved_origin!(uri, config)
        ensure_pack_headers_safe!(request_headers, config)
        response = run_with_retries(request_method, uri, request_headers, request_body, config)
        ensure_approved_origin!(response.env.url, config)
        if !never_error && !(200..299).cover?(response.status)
          filtered_url = filtered_url_for_logging(config["url"], config["query_params"])
          raise_node_error!(
            "HTTP #{config["method"]} #{filtered_url} failed with status #{response.status}",
            description: (error_body_description(response) unless config["redact_error_body"]),
          )
        end

        parsed =
          DiscourseWorkflows::Nodes::HttpRequest::ResponseParser.parse(
            response,
            max_size_kb: config["max_response_size_kb"],
            log: @exec_ctx.log,
          )
        Response.new(
          status: parsed[:status],
          headers: parsed[:headers],
          body: parsed[:body],
          status_message: parsed[:status_message],
        )
      end

      private

      def ensure_approved_origin!(url, config)
        allowed = config["allowed_origins"]
        return if allowed.nil?

        uri = URI.parse(url.to_s)
        unless allowed.is_a?(Array) && allowed.any? && uri.is_a?(URI::HTTPS) && uri.host.present? &&
                 uri.userinfo.nil?
          raise_node_error!(
            I18n.t("discourse_workflows.node_packs.errors.destination_not_approved"),
          )
        end
        port = uri.port == uri.default_port ? nil : uri.port
        origin = "#{uri.scheme.downcase}://#{uri.host.downcase}#{":#{port}" if port}"
        return if allowed.include?(origin)

        raise_node_error!(I18n.t("discourse_workflows.node_packs.errors.destination_not_approved"))
      rescue URI::InvalidURIError
        raise_node_error!(I18n.t("discourse_workflows.node_packs.errors.destination_not_approved"))
      end

      def ensure_pack_headers_safe!(headers, config)
        return if config["allowed_origins"].nil?
        return unless headers.keys.any? { |name| name.to_s.match?(PACK_FORBIDDEN_HEADERS) }

        raise_node_error!(I18n.t("discourse_workflows.node_packs.errors.header_forbidden"))
      end

      def error_body_description(response)
        body = response.body.to_s.scrub("").strip
        return if body.empty?
        return body if body.bytesize <= ERROR_BODY_MAX_BYTES

        "#{body.byteslice(0, ERROR_BODY_MAX_BYTES).scrub("")}…"
      end

      def build_config(method, url, headers, body, options)
        config =
          options.to_h.stringify_keys.merge(
            "method" => method.to_s.upcase,
            "url" => url,
            "headers" => headers,
          )
        config["body"] = body unless body.nil?
        config
      end

      def run_with_retries(method, uri, headers, body, config)
        attempts = max_retries(config, method) + 1
        statuses = retry_statuses(config)
        response = nil

        attempts.times do |attempt|
          response = connection.run_request(method, uri.to_s, body, headers)
          break if statuses.exclude?(response.status) || attempt >= attempts - 1
        end

        response
      end

      def connection
        @connection ||=
          Faraday.new(nil, request: request_options) do |f|
            f.adapter FinalDestination::FaradayAdapter
          end
      end

      def request_options
        { timeout: TIMEOUT_SECONDS, open_timeout: TIMEOUT_SECONDS, write_timeout: TIMEOUT_SECONDS }
      end

      def max_retries(config, method)
        config.fetch("max_retries") { default_max_retries(method) }.to_i.clamp(0, 5)
      end

      def default_max_retries(_method)
        DEFAULT_MAX_RETRIES
      end

      def retry_statuses(config)
        statuses = config["retry_statuses"]
        return DEFAULT_RETRY_STATUSES if statuses.blank?

        Set.new(Array(statuses).map(&:to_i))
      end
    end
  end
end
