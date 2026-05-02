# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    class HttpClient
      Response = Struct.new(:status, :headers, :body, keyword_init: true)

      TIMEOUT_SECONDS = 30
      DEFAULT_GET_MAX_RETRIES = 1
      DEFAULT_RETRY_STATUSES = Set[429, 500, 502, 503, 504].freeze

      def initialize(exec_ctx)
        @exec_ctx = exec_ctx
      end

      def request(method:, url:, headers: {}, body: nil, options: {})
        config = build_config(method, url, headers, body, options)
        request_method, uri, request_headers, request_body =
          DiscourseWorkflows::Nodes::HttpRequest::RequestBuilder.new(config, @exec_ctx).build
        never_error = config.fetch("never_error") { false }
        response = run_with_retries(request_method, uri, request_headers, request_body, config)
        if !never_error && !(200..299).cover?(response.status)
          raise "HTTP request failed with status #{response.status}"
        end

        parsed = DiscourseWorkflows::Nodes::HttpRequest::ResponseParser.parse(response)
        Response.new(status: parsed[:status], headers: parsed[:headers], body: parsed[:body])
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
        response = nil

        attempts.times do |attempt|
          response = connection.run_request(method, uri.to_s, body, headers)
          break unless retry_response?(response, config) && attempt < attempts - 1
        end

        response
      end

      def connection
        Faraday.new(nil, request: request_options) do |f|
          f.adapter FinalDestination::FaradayAdapter
        end
      end

      def request_options
        { timeout: TIMEOUT_SECONDS, open_timeout: TIMEOUT_SECONDS, write_timeout: TIMEOUT_SECONDS }
      end

      def retry_response?(response, config)
        retry_statuses(config).include?(response.status)
      end

      def max_retries(config, method)
        config.fetch("max_retries") { default_max_retries(method) }.to_i.clamp(0, 5)
      end

      def default_max_retries(method)
        method == :get ? DEFAULT_GET_MAX_RETRIES : 0
      end

      def retry_statuses(config)
        statuses = config["retry_statuses"]
        return DEFAULT_RETRY_STATUSES if statuses.blank?

        Set.new(Array(statuses).map(&:to_i))
      end
    end
  end
end
