# frozen_string_literal: true

module DiscourseAi
  module Completions
    class ThinkingConfig
      VALUES = %w[none minimal low medium high xhigh max].freeze

      attr_reader :canonical_effort,
                  :provider_effort,
                  :thinking_token_budget,
                  :visible_output_tokens,
                  :provider_output_tokens,
                  :reserved_output_tokens

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
