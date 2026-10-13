# frozen_string_literal: true

module DiscourseAi
  module Decisions
    class InferenceError < Error
      RETRYABLE_STATUSES = [408, 429, 500, 502, 503, 504, 529].freeze
      MAX_MESSAGE_LENGTH = 500

      attr_reader :http_status, :retry_after

      def self.from_response(response)
        body =
          begin
            JSON.parse(response.body.to_s)
          rescue JSON::ParserError
            nil
          end

        detail =
          if body.is_a?(Hash)
            error = body["error"]
            error.is_a?(Hash) ? error["message"] : error || body["detail"] || body["message"]
          end
        detail = detail.to_json if detail.present? && !detail.is_a?(String)

        new(
          "Decision model request failed with status #{response.status}#{": #{detail}" if detail.present?}",
          http_status: response.status,
          retry_after: Integer(response.headers["retry-after"].to_s, exception: false),
        )
      end

      # @param http_status [Integer, nil] nil when the request never got a response
      def initialize(message, http_status: nil, retry_after: nil)
        @http_status = http_status
        @retry_after = retry_after
        super(sanitize(message))
      end

      def retryable?
        http_status.nil? || RETRYABLE_STATUSES.include?(http_status)
      end

      private

      def sanitize(message)
        message
          .to_s
          .gsub(/\b(?:sk|key)-[A-Za-z0-9_-]{8,}\b/i, "[REDACTED]")
          .gsub(/(?:bearer|api[-_ ]?key)\s*[:=]?\s*[^\s,;]+/i, "[REDACTED]")
          .squish
          .first(MAX_MESSAGE_LENGTH)
      end
    end
  end
end
