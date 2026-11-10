# frozen_string_literal: true

module DiscourseAi
  module Completions
    class ThinkingConfig
      VALUES = %w[none minimal low medium high xhigh max].freeze

      attr_reader :canonical_effort,
                  :provider_effort,
                  :output_effort,
                  :thinking_token_budget,
                  :visible_output_tokens,
                  :provider_output_tokens,
                  :reserved_output_tokens

      # Rough provider-agnostic thinking allowances (mirrors the Anthropic
      # effort budgets) used to reserve thinking room on top of a visible
      # response cap when translating it to a provider ceiling. "none" still
      # reserves room: some models floor at low and think anyway.
      RESPONSE_ALLOWANCES = {
        "none" => 4096,
        "minimal" => 1024,
        "low" => 4096,
        "medium" => 8192,
        "high" => 16_384,
        "xhigh" => 32_768,
        "max" => 32_768,
      }.freeze

      def self.response_allowance(effort)
        RESPONSE_ALLOWANCES.fetch(normalize_effort(effort).to_s, 0)
      end

      # Allowance for a call on a specific model: the per-call effort when
      # given, otherwise reasoning configured in the model's provider params.
      def self.response_allowance_for(llm_model:, effort:)
        return response_allowance(effort) if normalize_effort(effort)
        return 0 if llm_model.nil?

        configured_tokens = llm_model.lookup_custom_param("reasoning_tokens").to_i
        return configured_tokens.clamp(1024, 32_768) if configured_tokens.positive?

        allowance = response_allowance(llm_model.lookup_custom_param("reasoning_effort"))
        return allowance if allowance.positive?

        if llm_model.lookup_custom_param("enable_reasoning") ||
             llm_model.lookup_custom_param("adaptive_thinking") ||
             llm_model.lookup_custom_param("reasoning_mode")
          response_allowance("medium")
        else
          0
        end
      end

      def self.normalize_effort(value)
        value = value.to_s.strip
        return if value.blank? || value == "default"
        value if VALUES.include?(value)
      end

      def self.disabled(canonical_effort: nil)
        new(canonical_effort: canonical_effort, enabled: false)
      end

      def self.explicit_none
        new(canonical_effort: "none", enabled: false, explicit_none: true)
      end

      def self.unsupported(canonical_effort: nil)
        new(canonical_effort: canonical_effort, enabled: false, unsupported: true)
      end

      def initialize(
        canonical_effort: nil,
        provider_effort: nil,
        output_effort: nil,
        enabled: false,
        explicit_none: false,
        unsupported: false,
        thinking_token_budget: nil,
        visible_output_tokens: nil,
        provider_output_tokens: nil,
        reserved_output_tokens: nil,
        strip_temperature: false,
        strip_top_p: false
      )
        @canonical_effort = canonical_effort
        @provider_effort = provider_effort
        @output_effort = output_effort
        @enabled = enabled
        @explicit_none = explicit_none
        @unsupported = unsupported
        @thinking_token_budget = thinking_token_budget
        @visible_output_tokens = visible_output_tokens
        @provider_output_tokens = provider_output_tokens
        @reserved_output_tokens = reserved_output_tokens
        @strip_temperature = strip_temperature
        @strip_top_p = strip_top_p
      end

      def enabled?
        @enabled
      end

      def explicit_none?
        @explicit_none
      end

      def unsupported?
        @unsupported
      end

      def strip_temperature?
        @strip_temperature
      end

      def strip_top_p?
        @strip_top_p
      end
    end
  end
end
