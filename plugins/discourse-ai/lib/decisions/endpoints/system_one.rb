# frozen_string_literal: true

module DiscourseAi
  module Decisions
    module Endpoints
      class SystemOne < Base
        WIRE_TYPES = { yes_no: "noul", choice: "choice", score: "score" }.freeze

        def provider_id
          AiApiAuditLog::Provider::SystemOne
        end

        def payload(state:, questions:, images:)
          payload = {
            model: decision_model.name,
            state:,
            questions: questions.to_h { |question| [question.name, wire_question(question)] },
          }
          payload[:images] = images if images.present?
          payload
        end

        def parse(body, questions)
          if !body.is_a?(Hash) || !body["answers"].is_a?(Hash)
            malformed!("answers must be an object")
          end
          validate_names!(body["answers"], questions)
          questions.map do |question|
            raw = body["answers"][question.name]
            malformed!("invalid answer for #{question.name}") if !raw.is_a?(Hash)
            probabilities = raw["probabilities"]
            if question.type == :score && raw["type"] != "refusal"
              keys = question.levels.each_index.map(&:to_s)
              if !probabilities.is_a?(Hash) || probabilities.keys.sort != keys.sort
                malformed!("expected one probability per level for #{question.name}")
              end
              probabilities = keys.map { |key| probabilities[key] }
            end
            parse_answer(
              question,
              raw,
              WIRE_TYPES.fetch(question.type),
              probability: raw["noul"],
              probabilities:,
            )
          end
        end

        private

        def wire_question(question)
          wire = { type: WIRE_TYPES.fetch(question.type), instructions: question.instructions }
          wire[:criteria] = question.choices.index_with(&:itself) if question.type == :choice
          wire[:criteria] = question.levels if question.type == :score
          wire
        end
      end
    end
  end
end
