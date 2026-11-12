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
          input = state.is_a?(String) ? state : state.to_json
          if images.present?
            content = [{ type: "input_text", text: input }]
            images.each { |image| content << { type: "input_image", image_url: image } }
            input = [{ role: "user", content: }]
          end
          {
            model: decision_model.name,
            input:,
            questions: questions.map { |question| wire_question(question) },
          }
        end

        def audit_payload(payload)
          payload = payload.deep_dup
          if payload[:input].is_a?(Array)
            payload[:input].each do |message|
              message[:content].each do |content|
                next if content[:type] != "input_image"

                header, data = content[:image_url].split(",", 2)
                mime_type = header.delete_prefix("data:").delete_suffix(";base64")
                content[:image_url] = redacted_image(data, mime_type:)
              end
            end
          end
          payload
        end

        def parse(body, questions)
          if !body.is_a?(Hash) || !body["answers"].is_a?(Array) || !body["answers"].all?(Hash)
            malformed!("answers must be a list of objects")
          end
          raw_answers = body["answers"]
          if raw_answers.map { |answer| answer["name"] }.uniq.size != raw_answers.size
            malformed!("duplicate answers")
          end
          raw_answers = raw_answers.index_by { |answer| answer["name"] }
          validate_names!(raw_answers, questions)
          questions.map do |question|
            raw = raw_answers.fetch(question.name)
            probabilities = nil
            if question.type != :yes_no && raw["type"] != "refusal"
              entries = raw["probabilities"]
              if !entries.is_a?(Array) || !entries.all?(Hash)
                malformed!("probabilities must be a list of objects")
              end
              values = entries.map { |entry| entry["value"] }
              expected =
                question.type == :choice ? question.choices : question.levels.each_index.to_a
              if values.uniq.size != values.size || values.to_set != expected.to_set
                malformed!("expected one probability per choice or level")
              end
              probabilities = entries.to_h { |entry| [entry["value"], entry["probability"]] }
              probabilities = expected.map { |value| probabilities[value] } if question.type ==
                :score
            end
            parse_answer(
              question,
              raw,
              WIRE_TYPES.fetch(question.type),
              probability: raw["probability"],
              probabilities:,
            )
          end
        end

        private

        def wire_question(question)
          wire = {
            type: WIRE_TYPES.fetch(question.type),
            name: question.name,
            instructions: question.instructions,
          }
          wire[:choices] = question.choices.map { |value| { value: } } if question.type == :choice
          wire[:levels] = question.levels.map { |label| { label: } } if question.type == :score
          wire
        end
      end
    end
  end
end
