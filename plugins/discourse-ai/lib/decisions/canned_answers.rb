# frozen_string_literal: true

module DiscourseAi
  module Decisions
    # Test double for decision model calls; see DiscourseAi::Decisions.with_canned_answers.
    class CannedAnswers
      class << self
        attr_accessor :current
      end

      attr_reader :calls

      # @param answers [Hash{Symbol, String => Object}] question name => canned value:
      #   - yes_no: probability (Float) or true/false
      #   - choice: chosen value (String) or `{ value => probability }`
      #   - score: chosen level label (String) or `{ label => probability }`
      #   - `:refusal` for any type
      # @param error [Exception, nil] raised by every call instead of answering
      def initialize(answers, error: nil)
        @answers = answers.transform_keys(&:to_s)
        @error = error
        @calls = []
        @used = Set.new
      end

      def decide(state:, questions:, images:, user:, feature_name:, feature_context:)
        @calls << { state:, questions:, images:, user:, feature_name:, feature_context: }
        raise @error if @error

        answers =
          questions.map do |question|
            if !@answers.key?(question.name)
              raise ArgumentError, "No canned answer for question #{question.name.inspect}"
            end
            @used << question.name
            build_answer(question, @answers[question.name])
          end

        Result.new(answers:, provider_model: "canned", input_tokens: 0, output_tokens: 0)
      end

      def verify_all_used!
        unused = @answers.keys - @used.to_a
        if unused.present? && @error.nil?
          raise ArgumentError, "Canned answers never asked for: #{unused.join(", ")}"
        end
      end

      private

      def build_answer(question, value)
        return Answers::Refusal.new(name: question.name) if value == :refusal

        case question.type
        when :yes_no
          probability = value == true ? 1.0 : value == false ? 0.0 : Float(value)
          Answers::YesNo.new(name: question.name, probability:)
        when :choice
          values = question.choices.map { |choice| choice[:value] }
          probabilities = distribution(question, values, value)
          Answers::Choice.new(
            name: question.name,
            choice: probabilities.max_by(&:last).first,
            probabilities:,
            confidence: probabilities.values.max,
          )
        when :score
          labels = question.levels.map { |level| level[:label] }
          probabilities = distribution(question, labels, value)
          Answers::Score.new(
            name: question.name,
            score: labels.each_with_index.sum { |label, index| probabilities[label] * index },
            level: probabilities.max_by(&:last).first,
            probabilities:,
            confidence: probabilities.values.max,
          )
        end
      end

      def distribution(question, keys, value)
        if value.is_a?(Hash)
          value = value.transform_keys(&:to_s)
          unknown = value.keys - keys
          if unknown.present?
            raise ArgumentError, "Unknown options for #{question.name}: #{unknown.join(", ")}"
          end
          keys.index_with { |key| value[key].to_f }
        else
          if keys.exclude?(value.to_s)
            raise ArgumentError, "#{value.inspect} is not an option for #{question.name}"
          end
          keys.index_with { |key| key == value.to_s ? 1.0 : 0.0 }
        end
      end
    end
  end
end
