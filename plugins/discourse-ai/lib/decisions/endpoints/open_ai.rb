# frozen_string_literal: true

module DiscourseAi
  module Decisions
    module Endpoints
      class OpenAi < Base
        WIRE_TYPES = { yes_no: "predicate", choice: "choice", score: "score" }.freeze

        def provider_id
          AiApiAuditLog::Provider::OpenAiDecisions
        end

        def payload(state:, questions:, images:)
          {
            model: decision_model.name,
            input: wire_input(state, images),
            questions: questions.map { |question| wire_question(question) },
          }
        end

        def parse(body, questions)
          raw_answers = body["answers"]
          if !raw_answers.is_a?(Array)
            raise InferenceError.new("Decision model response has no answers", http_status: 200)
          end
          raw_answers = raw_answers.index_by { |answer| answer["name"] }

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
                yes_no_answer(question, raw["probability"])
              when :choice
                choice_answer(
                  question,
                  raw["choice"],
                  probabilities_by(raw, "value") { |value| value.to_s },
                  raw["confidence"],
                )
              when :score
                probabilities = probabilities_by(raw, "value")
                score_answer(
                  question,
                  raw["score"],
                  question.levels.each_index.map { |index| probabilities[index] },
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

        def probabilities_by(raw, key)
          Array(raw["probabilities"]).to_h do |entry|
            value = entry.is_a?(Hash) ? entry[key] : nil
            value = yield(value) if block_given?
            [value, entry.is_a?(Hash) ? entry["probability"] : nil]
          end
        end

        def wire_input(state, images)
          text = state.is_a?(String) ? state : state.to_json
          return text if images.blank?

          content = [{ type: "input_text", text: text }]
          images.each { |image| content << { type: "input_image", image_url: image } }
          [{ role: "user", content: content }]
        end

        def wire_question(question)
          wire = {
            type: WIRE_TYPES.fetch(question.type),
            name: question.name,
            instructions: question.instructions,
          }

          case question.type
          when :choice
            wire[:choices] = question.choices
          when :score
            wire[:levels] = question.levels.map do |level|
              { label: level[:label], description: level[:description] || level[:label] }
            end
          end

          wire
        end
      end
    end
  end
end
