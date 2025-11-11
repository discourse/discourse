# frozen_string_literal: true

require_relative "base"

module DiscourseAi
  module Evals
    module Runners
      class Inference < Base
        OPERATIONS = {
          "generate_concepts" => {
            persona: DiscourseAi::Personas::ConceptFinder,
            schema_key: :concepts,
          },
          "match_concepts" => {
            persona: DiscourseAi::Personas::ConceptMatcher,
            schema_key: :matching_concepts,
          },
          "deduplicate_concepts" => {
            persona: DiscourseAi::Personas::ConceptDeduplicator,
            schema_key: :streamlined_tags,
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
        end

        private

        attr_reader :operation

        def generate_concepts(args, llm)
          content = conversation_to_text(args)
          raise ArgumentError, "Missing input for generate concepts eval" if content.blank?

          persona = persona_instance(operation)
          context =
            build_ctx.tap do |ctx|
              ctx.messages = [{ type: :user, content: content }]
              ctx.inferred_concepts = args[:existing_concepts] || []
            end

          values = capture_structured_output(persona, llm, context, operation)
          format_response(values)
        end

        def match_concepts(args, llm)
          content = conversation_to_text(args)
          candidates = args[:concepts].to_a.map(&:to_s)
          if content.blank? || candidates.empty?
            raise ArgumentError, "Match concepts eval requires :input/:conversation and :concepts"
          end

          persona = persona_instance(operation)

          context =
            build_ctx.tap do |ctx|
              ctx.messages = [{ type: :user, content: content }]
              ctx.inferred_concepts = candidates
            end

          values = capture_structured_output(persona, llm, context, operation)
          format_response(values)
        end

        def deduplicate_concepts(args, llm)
          candidates = args[:concepts].to_a.map(&:to_s)
          raise ArgumentError, "Deduplicate concepts eval requires :concepts" if candidates.empty?

          persona = persona_instance(operation)

          context =
            build_ctx.tap { |ctx| ctx.messages = [{ type: :user, content: candidates.join(", ") }] }

          values = capture_structured_output(persona, llm, context, operation)
          format_response(values)
        end

        def persona_instance(op)
          config = OPERATIONS.fetch(op) { raise ArgumentError }
          persona_klass = config.dig(:persona)
          persona_id = DiscourseAi::Personas::Persona.system_personas[persona_klass]
          persona_record = AiPersona.find_by_id_from_cache(persona_id)

          persona_record&.class_instance&.new || persona_klass.new
        end

        def capture_structured_output(persona, llm, context, op)
          schema = OPERATIONS.fetch(op)
          schema_key = schema[:schema_key]
          schema_type = schema[:schema_type]

          bot = DiscourseAi::Personas::Bot.as(Discourse.system_user, persona: persona, model: llm)
          structured_output = nil

          bot.reply(context) do |partial, _, type|
            structured_output = partial if type == :structured_output
          end

          return [] unless structured_output && schema_key

          structured_output.read_buffered_property(schema_key)
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
