# frozen_string_literal: true

module DiscourseAi
  module Decisions
    class Result
      # `provider_model` is the version the provider reports, e.g. "jev-1.13.0".
      attr_reader :answers, :provider_model, :audit_log_id, :input_tokens, :output_tokens

      # @param answers [Array] answer objects from DiscourseAi::Decisions::Answers
      def initialize(
        answers:,
        provider_model: nil,
        audit_log_id: nil,
        input_tokens: nil,
        output_tokens: nil
      )
        @answers = answers.index_by(&:name)
        @provider_model = provider_model
        @audit_log_id = audit_log_id
        @input_tokens = input_tokens&.to_i
        @output_tokens = output_tokens&.to_i
      end

      def [](name)
        answers.fetch(name.to_s) do
          raise KeyError, "No answer for #{name.inspect}, expected one of #{answers.keys.inspect}"
        end
      end

      def refusals
        answers.values.select(&:refusal?)
      end

      def complete?
        refusals.empty?
      end

      def to_h
        {
          model: provider_model,
          audit_log_id:,
          usage: {
            input_tokens:,
            output_tokens:,
          },
          answers: answers.transform_values(&:to_h),
        }
      end

      def as_json(*) = to_h.as_json
    end
  end
end
