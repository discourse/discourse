# frozen_string_literal: true

module DiscourseAi
  module Decisions
    module Endpoints
      class Base
        def self.for(decision_model)
          case decision_model.provider
          when DecisionModel::SYSTEM_ONE
            SystemOne.new(decision_model)
          when DecisionModel::OPEN_AI
            OpenAi.new(decision_model)
          else
            raise ArgumentError, "Unknown decision model provider: #{decision_model.provider}"
          end
        end

        attr_reader :decision_model

        def initialize(decision_model)
          @decision_model = decision_model
        end

        def provider_id
          raise NotImplementedError
        end

        # @param state [String, Hash, Array]
        # @param questions [Array<Question>]
        # @param images [Array<String>] base64 data URLs
        # @return [Hash]
        def payload(state:, questions:, images:)
          raise NotImplementedError
        end

        # @param body [Hash] parsed response body
        # @param questions [Array<Question>]
        # @return [Hash] `answers:`, `provider_model:`, `input_tokens:`, `output_tokens:`
        # @raise [InferenceError] when the response doesn't match the questions
        def parse(body, questions)
          raise NotImplementedError
        end

        def headers
          headers = { "Content-Type" => "application/json" }
          api_key = decision_model.api_key
          headers["Authorization"] = "Bearer #{api_key}" if api_key.present?
          headers
        end

        private

        def yes_no_answer(question, probability)
          Answers::YesNo.new(name: question.name, probability: number!(question, probability))
        end

        def choice_answer(question, choice, probabilities, confidence)
          values = question.choices.map { |option| option[:value] }
          malformed!(question, "unknown choice #{choice.inspect}") if values.exclude?(choice)

          Answers::Choice.new(
            name: question.name,
            choice: choice,
            probabilities: values.index_with { |value| number!(question, probabilities[value]) },
            confidence: number!(question, confidence),
          )
        end

        # @param probabilities [Array<Numeric>] one per level, lowest first
        def score_answer(question, score, probabilities, confidence)
          labels = question.levels.map { |level| level[:label] }
          if probabilities.size != labels.size
            malformed!(question, "expected #{labels.size} level probabilities")
          end
          probabilities = probabilities.map { |probability| number!(question, probability) }

          Answers::Score.new(
            name: question.name,
            score: number!(question, score),
            level: labels[probabilities.each_with_index.max[1]],
            probabilities: labels.zip(probabilities).to_h,
            confidence: number!(question, confidence),
          )
        end

        def number!(question, value)
          malformed!(question, "expected a number, got #{value.inspect}") if !value.is_a?(Numeric)
          value.to_f
        end

        def malformed!(question, detail)
          raise InferenceError.new(
                  "Malformed answer for #{question.name}: #{detail}",
                  http_status: 200,
                )
        end
      end
    end
  end
end
