# frozen_string_literal: true

require_relative "base"

module DiscourseAi
  module Evals
    module Runners
      class Inference < Base
        OPERATIONS = {
          "generate_concepts" => {
            persona_class: DiscourseAi::Personas::ConceptFinder,
            schema_key: :concepts,
            schema_type: "array",
          },
          "match_concepts" => {
            persona_class: DiscourseAi::Personas::ConceptMatcher,
            schema_key: :matching_concepts,
            schema_type: "array",
          },
          "deduplicate_concepts" => {
            persona_class: DiscourseAi::Personas::ConceptDeduplicator,
            schema_key: :streamlined_tags,
            schema_type: "array",
          },
        }.freeze

        def self.can_handle?(feature_name)
          feature_name&.start_with?("inference:")
        end

        def initialize(feature)
          @operation = feature
        end

        def run(eval_case, llm)
          args = eval_case.args || {}

          response =
            case operation
            when "generate_concepts"
              generate_concepts(args, llm)
            when "match_concepts"
              match_concepts(args, llm)
            when "deduplicate_concepts"
              deduplicate_concepts(args, llm)
            else
              raise ArgumentError, "Unsupported inference feature '#{operation}'"
            end

          response
        end

        private

        attr_reader :operation

        def generate_concepts(args, llm)
          content = conversation_to_text(args)
          raise ArgumentError, "Missing input for generate concepts eval" if content.blank?

          persona, user = persona_bundle(operation)
          context =
            build_ctx.tap do |ctx|
              ctx.messages = [{ type: :user, content: content }]
              ctx.inferred_concepts = args[:existing_concepts] || []
            end

          values = capture_structured_output(persona, user, llm, context, operation)
          wrap_result(format_response(values), { query: content })
        end

        def match_concepts(args, llm)
          content = conversation_to_text(args)
          candidates = args[:concepts].to_a.map(&:to_s)
          if content.blank? || candidates.empty?
            raise ArgumentError, "Match concepts eval requires :input/:conversation and :concepts"
          end

          persona, user = persona_bundle(operation)

          context =
            build_ctx.tap do |ctx|
              ctx.messages = [{ type: :user, content: content }]
              ctx.inferred_concepts = candidates
            end

          values = capture_structured_output(persona, user, llm, context, operation)
          wrap_result(format_response(values), { query: content, concepts: candidates })
        end

        def deduplicate_concepts(args, llm)
          candidates = args[:concepts].to_a.map(&:to_s)
          raise ArgumentError, "Deduplicate concepts eval requires :concepts" if candidates.empty?

          persona, user = persona_bundle(operation)

          context =
            build_ctx.tap { |ctx| ctx.messages = [{ type: :user, content: candidates.join(", ") }] }

          values = capture_structured_output(persona, user, llm, context, operation)
          wrap_result(format_response(values), { concepts: candidates })
        end

        def persona_bundle(op)
          config = OPERATIONS.fetch(op) { raise ArgumentError }
          persona_klass = config.fetch(:persona_class)

          resolve_persona(persona_class: persona_klass)
        end

        def capture_structured_output(persona, user, llm, context, op)
          schema = OPERATIONS.fetch(op)
          schema_key = schema[:schema_key]
          schema_type = schema[:schema_type] || "array"

          bot = DiscourseAi::Personas::Bot.as(user, persona: persona, model: llm)
          capture_structured_response(
            bot,
            context,
            schema_key: schema_key,
            schema_type: schema_type,
          )
        end

        def conversation_to_text(args)
          if args[:conversation].present?
            Array(args[:conversation]).join("\n\n")
          else
            args[:input].to_s
          end
        end

        def format_response(values)
          if values.is_a?(Array)
            values.map { |item| item.to_s.strip }.reject(&:blank?).join("\n")
          else
            values.to_s
          end
        end

        def build_ctx
          DiscourseAi::Personas::BotContext.new(
            user: Discourse.system_user,
            skip_tool_details: true,
            feature_name: "evals/inference/#{operation}",
          )
        end
      end
    end
  end
end
