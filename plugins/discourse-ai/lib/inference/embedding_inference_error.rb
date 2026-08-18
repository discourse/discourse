# frozen_string_literal: true

module DiscourseAi
  module Inference
    class EmbeddingInferenceError < StandardError
      TERMINAL_CATEGORIES = %i[
        quota_exhausted
        authentication_failed
        authorization_failed
        invalid_configuration
      ].freeze
      RETRYABLE_CATEGORIES = %i[rate_limited provider_unavailable].freeze
      MAX_MESSAGE_LENGTH = 500

      attr_reader :provider,
                  :http_status,
                  :provider_error_type,
                  :provider_error_code,
                  :category,
                  :retry_after

      def self.from_response(provider:, response:)
        body =
          begin
            parsed = JSON.parse(response.body.to_s)
            parsed.is_a?(Hash) ? parsed : {}
          rescue JSON::ParserError
            {}
          end
        attributes = provider_attributes(provider, body)
        new(
          provider: provider,
          http_status: response.status,
          provider_error_type: attributes[:type],
          provider_error_code: attributes[:code],
          category: classify(provider, response.status.to_i, attributes),
          retry_after: retry_after(response.headers["retry-after"]),
          message: attributes[:message],
        )
      end

      def initialize(
        provider:,
        category:,
        http_status: nil,
        provider_error_type: nil,
        provider_error_code: nil,
        retry_after: nil,
        message: nil
      )
        @provider = provider.to_s.first(100)
        @category = category.to_sym
        @http_status = http_status&.to_i
        @provider_error_type = provider_error_type.to_s.first(100).presence
        @provider_error_code = provider_error_code.to_s.first(100).presence
        @retry_after = retry_after
        super(sanitize(message).presence || "Embedding provider request failed (#{category})")
      end

      def terminal?
        TERMINAL_CATEGORIES.include?(category)
      end

      def retryable?
        RETRYABLE_CATEGORIES.include?(category)
      end

      class << self
        private

        def provider_attributes(provider, body)
          error =
            case provider.to_s
            when EmbeddingDefinition::CLOUDFLARE
              Array(body["errors"]).first
            else
              body["error"]
            end
          return { message: error } if !error.is_a?(Hash)

          { type: error["type"] || error["status"], code: error["code"], message: error["message"] }
        end

        def classify(provider, status, attributes)
          evidence =
            [attributes[:type], attributes[:code]].compact.map { |value| value.to_s.downcase }
          if provider.to_s == EmbeddingDefinition::OPEN_AI &&
               evidence.intersect?(%w[insufficient_quota credit_balance_exhausted])
            return :quota_exhausted
          end

          return :authentication_failed if status == 401
          return :authorization_failed if status == 403
          return :rate_limited if status == 429
          return :provider_unavailable if status == 408 || status >= 500
          if evidence.intersect?(
               %w[invalid_argument invalid_model model_not_found deployment_notfound],
             )
            return :invalid_configuration
          end

          :request_rejected
        end

        def retry_after(value)
          return if value.blank?

          seconds = Integer(value, exception: false)
          seconds&.clamp(0, 300)
        end
      end

      private

      def sanitize(message)
        message
          .to_s
          .encode("UTF-8", invalid: :replace, undef: :replace, replace: "�")
          .gsub(/[[:cntrl:]]+/, " ")
          .gsub(/\b(?:sk|key)-[A-Za-z0-9_-]{8,}\b/i, "[REDACTED]")
          .gsub(/(?:bearer|api[-_ ]?key)\s*[:=]?\s*[^\s,;]+/i, "[REDACTED]")
          .squish
          .first(MAX_MESSAGE_LENGTH)
      end
    end
  end
end
