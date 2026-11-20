# frozen_string_literal: true

module DiscourseAi
  module Decisions
    class Result
      attr_reader :answers, :provider_model, :input_tokens, :output_tokens, :audit_log_id

      def initialize(
        answers:,
        provider_model: nil,
        input_tokens: nil,
        output_tokens: nil,
        audit_log_id: nil
      )
        @answers = answers.index_by(&:name).freeze
        @provider_model = provider_model
        @input_tokens = input_tokens
        @output_tokens = output_tokens
        @audit_log_id = audit_log_id
      end

      def [](name)
        answers.fetch(name.to_s)
      end

      def refusals
        answers.values.select(&:refusal?)
      end

      def to_h
        {
          provider_model:,
          input_tokens:,
          output_tokens:,
          audit_log_id:,
          answers: answers.transform_values(&:to_h),
        }
      end
    end
  end
end
