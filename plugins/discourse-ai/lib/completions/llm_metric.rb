# frozen_string_literal: true

module DiscourseAi
  module Completions
    class LlmMetric
      class << self
        # Records metrics for an LLM API call
        #
        # @param llm_model [LlmModel] The LLM model used for the call
        # @param feature_name [String] The feature that initiated the call
        # @param request_tokens [Integer] Number of input tokens
        # @param response_tokens [Integer] Number of output tokens
        # @param duration_ms [Float] Duration of the call in milliseconds
        # @param status [Symbol] Status of the call (:success or :error)
        def record(
          llm_model:,
          feature_name:,
          request_tokens:,
          response_tokens:,
          duration_ms:,
          status: :success
        )
          return if !defined?(::DiscoursePrometheus)

          labels = {
            db: RailsMultisite::ConnectionManagement.current_db,
            provider: llm_model.provider,
            model_name: llm_model.name,
            feature: feature_name || "unknown",
            seeded: llm_model.seeded?,
          }

          increment_counter(
            "discourse_ai_llm_calls_total",
            "Total number of LLM API calls",
            labels.merge(status: status),
          )

          if status == :success
            # Record request tokens
            increment_counter(
              "discourse_ai_llm_request_tokens_total",
              "Total number of input tokens sent to LLM APIs",
              labels,
              request_tokens,
            )

            increment_counter(
              "discourse_ai_llm_response_tokens_total",
              "Total number of output tokens received from LLM APIs",
              labels,
              response_tokens,
            )

            observe_histogram(
              "discourse_ai_llm_duration_seconds",
              "Duration of LLM API calls in seconds",
              labels,
              duration_ms / 1000.0,
            )
          end
        end

        private

        def increment_counter(name, description, labels, value = 1)
          metric = ::DiscoursePrometheus::InternalMetric::Custom.new
          metric.name = name
          metric.type = "Counter"
          metric.description = description
          metric.labels = labels
          metric.value = value
          $prometheus_client.send_json(metric.to_h) # rubocop:disable Style/GlobalVars
        end

        def observe_histogram(name, description, labels, value)
          metric = ::DiscoursePrometheus::InternalMetric::Custom.new
          metric.name = name
          metric.type = "Summary"
          metric.description = description
          metric.labels = labels
          metric.value = value
          $prometheus_client.send_json(metric.to_h) # rubocop:disable Style/GlobalVars
        end
      end
    end
  end
end
