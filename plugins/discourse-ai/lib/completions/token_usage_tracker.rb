# frozen_string_literal: true

module DiscourseAi
  module Completions
    class TokenUsageTracker
      def initialize(base_total: nil, base_request: nil, base_response: nil)
        @mutex = Mutex.new
        if base_request.nil? && base_response.nil?
          total = base_total.to_i
          initial_request = total / 2
          @request = initial_request
          @response = total - initial_request
        else
          if !base_total.nil?
            raise ArgumentError, "base_total cannot be combined with base_request/base_response"
          end
          if base_request.nil? || base_response.nil?
            raise ArgumentError, "base_request and base_response must both be provided"
          end

          @request = base_request.to_i
          @response = base_response.to_i
        end
      end

      def add_from_audit_log(log)
        # request_tokens = non-cached input (already excludes cached)
        # cache_write_tokens = newly cached (full cost)
        # cache_read_tokens = served from cache (1/10 cost)
        add_effective(
          request:
            log.request_tokens.to_i + log.cache_write_tokens.to_i +
              (log.cache_read_tokens.to_i * 0.1).to_i,
          response: log.response_tokens.to_i,
        )
      end

      def add_effective(request:, response:)
        @mutex.synchronize do
          @request += request.to_i
          @response += response.to_i
        end
      end

      def request
        @mutex.synchronize { @request }
      end

      def response
        @mutex.synchronize { @response }
      end

      def total
        @mutex.synchronize { @request + @response }
      end
    end
  end
end
