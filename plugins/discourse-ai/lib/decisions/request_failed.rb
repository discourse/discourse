# frozen_string_literal: true

module DiscourseAi
  module Decisions
    class RequestFailed < Error
      RETRYABLE_STATUSES = [408, 429, 500, 502, 503, 504, 529].freeze

      attr_reader :http_status, :retry_after

      def initialize(message, http_status: nil, retry_after: nil, retryable: false)
        super(message.to_s[0, 500])
        @http_status = http_status
        @retry_after = retry_after
        @retryable = retryable
      end

      def retryable?
        @retryable
      end

      def self.redact(text, api_key)
        text = text.to_s
        text = text.gsub(api_key, "[redacted]") if api_key.present?
        text.gsub(/Bearer\s+[^\s"',;]+/i, "Bearer [redacted]").gsub(
          /\b(?:sk|key)-[A-Za-z0-9_-]+/i,
          "[redacted]",
        )
      end

      def self.sanitize(message, api_key)
        redact(message, api_key)[0, 500]
      end

      def self.from_response(model, response)
        status = response.code.to_i
        body =
          begin
            JSON.parse(response.body.to_s)
          rescue JSON::ParserError
            nil
          end
        message =
          if body.is_a?(Hash)
            detail =
              body["error"] || body["detail"] || body["message"] || Array.wrap(body["errors"]).first
            detail = detail.is_a?(Hash) ? detail["message"] || detail.to_json : detail
            detail&.to_s&.gsub("AiError: ", "")
          end
        message = sanitize(message || response.message, model.api_key)
        delay = Float(response["Retry-After"], exception: false)
        delay = nil if delay && !delay.finite?
        new(
          "Request failed with status #{status}: #{message}",
          http_status: status,
          retry_after: delay,
          retryable: RETRYABLE_STATUSES.include?(status),
        )
      end
    end
  end
end
