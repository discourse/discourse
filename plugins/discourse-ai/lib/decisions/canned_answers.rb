# frozen_string_literal: true

module DiscourseAi
  module Decisions
    class CannedAnswers
      class << self
        attr_accessor :current
      end

      attr_reader :calls

      def initialize(answers)
        @answers = answers.transform_keys(&:to_s)
        @calls = []
      end

      def decide(state:, questions:, images:, user:, feature_name:)
        @calls << { state:, questions:, images:, user:, feature_name: }
        answers =
          questions.map do |question|
            value =
              @answers.fetch(question.name) do
                raise ArgumentError, "No canned answer for question #{question.name.inspect}"
              end
            next Answers::Refusal.new(name: question.name) if value == :refusal

            case question.type
            when :yes_no
              probability = value == true ? 1.0 : value == false ? 0.0 : value
              if !probability.is_a?(Numeric) || !probability.real? || !probability.finite? ||
                   !probability.between?(0, 1)
                raise ArgumentError, "Invalid canned probability for #{question.name}"
              end
              Answers::YesNo.new(name: question.name, probability: probability.to_f)
            when :choice, :score
              probabilities = distribution(question.choices || question.levels, value)
              label, confidence = probabilities.max_by(&:last)
              attributes = { name: question.name, probabilities:, confidence: }
              if question.type == :choice
                Answers::Choice.new(**attributes, choice: label)
              else
                score =
                  probabilities.values.each_with_index.sum do |level_probability, index|
                    level_probability * index
                  end
                Answers::Score.new(**attributes, score:, level: label)
              end
            end
          end
        Result.new(answers:, provider_model: "canned", input_tokens: 0, output_tokens: 0)
      end

      private

      def distribution(labels, value)
        if value.is_a?(String) && labels.include?(value)
          return labels.index_with { |label| label == value ? 1.0 : 0.0 }
        end
        value = value.transform_keys(&:to_s) if value.is_a?(Hash)
        if !value.is_a?(Hash) || (value.keys - labels).any? || value.empty?
          raise ArgumentError, "Invalid canned distribution"
        end
        probabilities = labels.index_with { |label| value.fetch(label, 0.0) }
        if probabilities.values.any? { |probability|
             !probability.is_a?(Numeric) || !probability.real? || !probability.finite? ||
               !probability.between?(0, 1)
           }
          raise ArgumentError, "Invalid canned probability"
        end
        probabilities
      end
    end
  end
end
