# frozen_string_literal: true

module DiscourseAi
  module Decisions
    module Endpoints
      # The System One API, served by hosted providers and self-hosted engines alike.
      class SystemOne < Base
        WIRE_TYPES = { yes_no: "noul", choice: "choice", score: "score" }.freeze

        def provider_id
          AiApiAuditLog::Provider::SystemOne
        end

        def payload(state:, questions:, images:)
          payload = {
            model: decision_model.name,
            state: state,
            questions: questions.to_h { |question| [question.name, wire_question(question)] },
          }
          payload[:images] = images if images.present?
          payload
        end

        def parse(body, questions)
          raw_answers = body["answers"]
          if !raw_answers.is_a?(Hash)
            raise InferenceError.new("Decision model response has no answers", http_status: 200)
          end

          answers =
            questions.map do |question|
              raw = raw_answers[question.name]
              malformed!(question, "missing") if !raw.is_a?(Hash)
              next Answers::Refusal.new(name: question.name) if raw["type"] == "refusal"

              wire_type = WIRE_TYPES.fetch(question.type)
              if raw["type"] != wire_type
                malformed!(question, "unexpected type #{raw["type"].inspect}")
              end

              case question.type
              when :yes_no
                yes_no_answer(question, raw["noul"])
              when :choice
                choice_answer(
                  question,
                  raw["choice"],
                  hash_or_empty(raw["probabilities"]),
                  raw["confidence"],
                )
              when :score
                probabilities = hash_or_empty(raw["probabilities"])
                score_answer(
                  question,
                  raw["score"],
                  question.levels.each_index.map { |index| probabilities[index.to_s] },
                  raw["confidence"],
                )
              end
            end

          {
            answers:,
            provider_model: body["model"],
            input_tokens: body.dig("usage", "input_tokens"),
            output_tokens: body.dig("usage", "output_tokens"),
          }
        end

        private

        def hash_or_empty(value)
          value.is_a?(Hash) ? value : {}
        end

        def wire_question(question)
          wire = { type: WIRE_TYPES.fetch(question.type), instructions: question.instructions }

          case question.type
          when :choice
            wire[:criteria] = question.choices.to_h do |choice|
              [choice[:value], choice[:description]]
            end
          when :score
            wire[:criteria] = question.levels.map { |level| level[:description] || level[:label] }
          end

          wire
        end
      end
    end
  end
end
