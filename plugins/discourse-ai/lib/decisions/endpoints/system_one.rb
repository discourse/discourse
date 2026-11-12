# frozen_string_literal: true

module DiscourseAi
  module Decisions
    module Endpoints
      class SystemOne < Base
        WIRE_TYPES = { yes_no: "noul", choice: "choice", score: "score" }.freeze

        def provider_id
          AiApiAuditLog::Provider::SystemOne
        end

        # Self-hosted System One engines sit behind the same routing proxy as
        # self-hosted LLMs, so they get the same registered routing headers.
        def headers(feature_name:, has_images:)
          context =
            RequestHeaders::Context.new(
              model: decision_model,
              feature_name:,
              has_images:,
              streaming: false,
            )
          headers = decision_model.custom_headers_for_request
          [super, RequestHeaders.for(context)].each do |authoritative_headers|
            authoritative_headers.each do |name, value|
              headers.delete_if { |existing_name, _| existing_name.casecmp?(name) }
              headers[name] = value
            end
          end
          headers
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

        def audit_payload(payload)
          payload = payload.deep_dup
          payload[:images]&.map! do |image|
            header, data = image.split(",", 2)
            mime_type = header.delete_prefix("data:").delete_suffix(";base64")
            redacted_image(data, mime_type:)
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
