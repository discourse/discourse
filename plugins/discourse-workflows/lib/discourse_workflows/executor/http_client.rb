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
        response = run_with_retries(request_method, uri, request_headers, request_body, config)
        if !never_error && !(200..299).cover?(response.status)
          filtered_url = filtered_url_for_logging(config["url"], config["query_params"])
          raise_node_error!(
            "HTTP #{config["method"]} #{filtered_url} failed with status #{response.status}",
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
