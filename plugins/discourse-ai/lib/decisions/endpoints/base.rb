# frozen_string_literal: true

module DiscourseAi
  module Decisions
    module Endpoints
      class Base
        # Token columns in the audit log and usage stats are 4-byte integers.
        MAX_TOKENS = 2_147_483_647

        def self.for(model)
          case model.provider
          when "system_one"
            SystemOne.new(model)
          when "typesafe"
            Typesafe.new(model)
          when "open_ai"
            OpenAi.new(model)
          else
            raise InvalidRequest, "Unknown decision model provider #{model.provider.inspect}"
          end
        end

        attr_reader :decision_model

        def initialize(decision_model)
          @decision_model = decision_model
        end

        def headers(feature_name:, has_images:)
          headers = { "Content-Type" => "application/json" }
          api_key = decision_model.api_key
          headers["Authorization"] = "Bearer #{api_key}" if api_key.present?
          headers
        end

        def audit_payload(payload)
          payload
        end

        # Token counts only feed usage stats, so unusable values become nil rather than
        # discarding valid answers.
        # @return [Array(Integer, Integer)] input and output tokens, either may be nil
        def usage(body)
          usage = body["usage"].is_a?(Hash) ? body["usage"] : {}
          usage
            .values_at("input_tokens", "output_tokens")
            .map do |count|
              if finite_number?(count) && count.between?(0, MAX_TOKENS) && count == count.to_i
                count.to_i
              end
            end
        end

        private

        def redacted_image(data, mime_type:)
          size = ActiveSupport::NumberHelper.number_to_human_size(data.length * 3 / 4)
          "[redacted #{mime_type}, #{size}]"
        end

        def validate_names!(answers, questions)
          if answers.keys.to_set != questions.map(&:name).to_set
            malformed!("every question must be answered exactly once")
          end
        end

        def parse_answer(question, raw, wire_type, probability:, probabilities:)
          if raw["type"] == "refusal"
            reason = raw["reason"] || raw["refusal"]
            if !reason.nil? && !reason.is_a?(String)
              malformed!("invalid refusal reason for #{question.name}")
            end
            return Answers::Refusal.new(name: question.name, reason:)
          end
          malformed!("unexpected type for #{question.name}") if raw["type"] != wire_type
          case question.type
          when :yes_no
            Answers::YesNo.new(name: question.name, probability: probability!(probability))
          when :choice
            choice_answer(question, raw["choice"], probabilities, raw["confidence"])
          when :score
            score_answer(question, raw["score"], probabilities, raw["confidence"])
          end
        end

        def choice_answer(question, choice, probabilities, confidence)
          malformed!("unknown choice for #{question.name}") if !question.choices.include?(choice)
          if !probabilities.is_a?(Hash) || probabilities.keys.sort != question.choices.sort
            malformed!("expected one probability per choice for #{question.name}")
          end
          Answers::Choice.new(
            name: question.name,
            choice:,
            probabilities:
              question.choices.index_with { |value| probability!(probabilities[value]) },
            confidence: confidence!(confidence),
          )
        end

        def score_answer(question, score, probabilities, confidence)
          if !probabilities.is_a?(Array) || probabilities.size != question.levels.size
            malformed!("expected one probability per level for #{question.name}")
          end
          probabilities = probabilities.map { |value| probability!(value) }
          if !finite_number?(score) || !score.between?(0, question.levels.size - 1)
            malformed!("invalid score for #{question.name}")
          end
          Answers::Score.new(
            name: question.name,
            score:,
            level: question.levels[probabilities.index(probabilities.max)],
            probabilities: question.levels.zip(probabilities).to_h,
            confidence: confidence!(confidence),
          )
        end

        def confidence!(value)
          value.nil? ? nil : probability!(value)
        end

        def probability!(value)
          if !finite_number?(value) || !value.between?(0, 1)
            malformed!("probability must be finite and in [0, 1]")
          end
          value
        end

        def finite_number?(value)
          value.is_a?(Numeric) && value.real? && value.finite?
        end

        def malformed!(detail)
          raise RequestFailed.new(
                  "Request failed: malformed response (#{detail})",
                  http_status: 200,
                )
        end
      end
    end
  end
end
