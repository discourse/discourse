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

      def self.redact(text, api_key, header_values: [])
        patterns = []
        variants =
          [api_key, *header_values].reject(&:blank?)
            .uniq
            .flat_map do |value|
              [value, value.to_json[1...-1]].uniq.map { |variant| [variant, value] }
            end
            .sort_by { |variant, _value| -variant.length }
        variants.each do |variant, value|
          pattern = Regexp.escape(variant)
          # Short configuration values must not redact parts of ordinary words or identifiers.
          if value != api_key && value.length < 8
            pattern =
              "(?<![[:alnum:]_-])(?<![[:alnum:]_]\\.)#{pattern}(?![[:alnum:]_-]|\\.[[:alnum:]_])"
          end
          patterns << Regexp.new(pattern)
        end
        patterns << /(?<bearer>Bearer\s+)[^\s"',;]+/i
        patterns << /\b(?:sk|key)-[A-Za-z0-9_-]+/i

        # One pass prevents overlapping values from redacting the replacement itself.
        text
          .to_s
          .gsub(Regexp.union(patterns)) do
            Regexp.last_match[:bearer] ? "Bearer [redacted]" : "[redacted]"
          end
      end

      def self.redact_response(text, api_key, header_values: [])
        parsed = JSON.parse(text.to_s)
        redact_json =
          lambda do |value|
            case value
            when Hash
              value.to_h do |key, child|
                # Header configuration values must not change response field names.
                [redact(key, api_key), redact_json.call(child)]
              end
            when Array
              value.map { |child| redact_json.call(child) }
            when String
              redact(value, api_key, header_values:)
            else
              value
            end
          end
        redact_json.call(parsed).to_json
      rescue JSON::ParserError
        redact(text, api_key, header_values:)
      end

      def self.sanitize(message, api_key, header_values: [])
        redact(message, api_key, header_values:)[0, 500]
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
        message =
          sanitize(
            message || response.message,
            model.api_key,
            header_values: model.custom_headers_for_request.values,
          )
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
