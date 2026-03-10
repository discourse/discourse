# frozen_string_literal: true

require_relative "base"

module DiscourseAi
  module Evals
    module Runners
      class Inference < Base
        OPERATIONS = {
          "generate_concepts" => {
            agent_class: DiscourseAi::Agents::ConceptFinder,
            schema_key: :concepts,
            schema_type: "array",
          },
          "match_concepts" => {
            agent_class: DiscourseAi::Agents::ConceptMatcher,
            schema_key: :matching_concepts,
            schema_type: "array",
          },
          "deduplicate_concepts" => {
            agent_class: DiscourseAi::Agents::ConceptDeduplicator,
            schema_key: :streamlined_tags,
            schema_type: "array",
          },
        }.freeze

        def self.can_handle?(feature_name)
          feature_name&.start_with?("inference:")
        end

        def run(eval_case, llm, execution_context:)
          args = eval_case.args || {}

          response =
            case feature_name
            when "generate_concepts"
              generate_concepts(args, llm, execution_context:)
            when "match_concepts"
              match_concepts(args, llm, execution_context:)
            when "deduplicate_concepts"
              deduplicate_concepts(args, llm, execution_context:)
            else
              raise ArgumentError, "Unsupported inference feature '#{feature_name}'"
            end

          response
        end

        private

        def generate_concepts(args, llm, execution_context:)
          content = conversation_to_text(args)
          raise ArgumentError, "Missing input for generate concepts eval" if content.blank?

          agent, user = agent_bundle(feature_name)
          context =
            build_ctx.tap do |ctx|
              ctx.messages = [{ type: :user, content: content }]
              ctx.inferred_concepts = args[:existing_concepts] || []
            end

          values =
            capture_structured_output(agent, user, llm, context, feature_name, execution_context:)
          wrap_result(format_response(values), { query: content })
        end

        def match_concepts(args, llm, execution_context:)
          content = conversation_to_text(args)
          candidates = args[:concepts].to_a.map(&:to_s)
          if content.blank? || candidates.empty?
            raise ArgumentError, "Match concepts eval requires :input/:conversation and :concepts"
          end

          agent, user = agent_bundle(feature_name)

          context =
            build_ctx.tap do |ctx|
              ctx.messages = [{ type: :user, content: content }]
              ctx.inferred_concepts = candidates
            end

          values =
            capture_structured_output(agent, user, llm, context, feature_name, execution_context:)
          wrap_result(format_response(values), { query: content, concepts: candidates })
        end

        def deduplicate_concepts(args, llm, execution_context:)
          candidates = args[:concepts].to_a.map(&:to_s)
          raise ArgumentError, "Deduplicate concepts eval requires :concepts" if candidates.empty?

          agent, user = agent_bundle(feature_name)

          context =
            build_ctx.tap { |ctx| ctx.messages = [{ type: :user, content: candidates.join(", ") }] }

          values =
            capture_structured_output(agent, user, llm, context, feature_name, execution_context:)
          wrap_result(format_response(values), { concepts: candidates })
        end

        def agent_bundle(op)
          config = OPERATIONS.fetch(op) { raise ArgumentError }
          agent_klass = config.fetch(:agent_class)

          resolve_agent(agent_class: agent_klass)
        end

        def capture_structured_output(agent, user, llm, context, op, execution_context:)
          schema = OPERATIONS.fetch(op)
          schema_key = schema[:schema_key]
          schema_type = schema[:schema_type] || "array"

          bot = DiscourseAi::Agents::Bot.as(user, agent: agent, model: llm)
          capture_structured_response(
            bot,
            context,
            schema_key: schema_key,
            schema_type: schema_type,
            execution_context:,
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
          DiscourseAi::Agents::BotContext.new(
            user: Discourse.system_user,
            skip_show_thinking: true,
            feature_name: "evals/inference/#{feature_name}",
          )
        end
      end
    end
  end
end
