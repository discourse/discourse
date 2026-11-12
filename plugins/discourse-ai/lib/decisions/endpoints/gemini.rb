# frozen_string_literal: true

module DiscourseAi
  module Decisions
    module Endpoints
      # Gemini Decisions API (POST /v1beta/decisions, model gemini-decision-1).
      class Gemini < Base
        WIRE_TYPES = { yes_no: "noul", choice: "choice", score: "score" }.freeze
        # Gemini identifies choices by key, and keys are capped at 128 characters.
        MAX_CHOICE_LENGTH = 128

        def provider_id
          AiApiAuditLog::Provider::GeminiDecisions
        end

        def headers(feature_name:, has_images:)
          headers = { "Content-Type" => "application/json" }
          api_key = decision_model.api_key
          headers["x-goog-api-key"] = api_key if api_key.present?
          headers
        end

        def payload(state:, questions:, images:)
          input = state.is_a?(String) ? state : state.to_json
          if images.present?
            input = [{ type: "text", text: input }]
            images.each do |image|
              header, data = image.split(",", 2)
              mime_type = header.delete_prefix("data:").delete_suffix(";base64")
              input << { type: "image", data:, mime_type: }
            end
          end
          {
            model: decision_model.name,
            input:,
            questions: questions.to_h { |question| [question.name, wire_question(question)] },
          }
        end

        def audit_payload(payload)
          payload = payload.deep_dup
          if payload[:input].is_a?(Array)
            payload[:input].each do |content|
              next if content[:type] != "image"

              content[:data] = redacted_image(content[:data], mime_type: content[:mime_type])
            end
          end
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

        def usage(body)
          usage = body["usage"].is_a?(Hash) ? body["usage"] : {}
          usage
            .values_at("total_input_tokens", "total_output_tokens")
            .map do |count|
              if finite_number?(count) && count.between?(0, MAX_TOKENS) && count == count.to_i
                count.to_i
              end
            end
        end

        private

        def wire_question(question)
          wire = { type: WIRE_TYPES.fetch(question.type), instructions: question.instructions }
          if question.type == :choice
            if question.choices.any? { |choice| choice.length > MAX_CHOICE_LENGTH }
              raise InvalidRequest,
                    "Question #{question.name.inspect} choices: must be at most #{MAX_CHOICE_LENGTH} characters for Gemini"
            end
            # The choice itself is the option key; an empty description is allowed.
            wire[:criteria] = question.choices.index_with { "" }
          end
          wire[:criteria] = question.levels if question.type == :score
          wire
        end
      end
    end
  end
end
