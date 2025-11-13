# frozen_string_literal: true

require_relative "base"

module DiscourseAi
  module Evals
    module Runners
      class Hyde < Base
        def self.can_handle?(feature_name)
          feature_name&.start_with?("embeddings:hyde")
        end

        def initialize(operation)
          @operation = operation
        end

        def run(eval_case, llm)
          args = normalize_args(eval_case.args)
          case_defs = Array(args.delete(:cases)).presence

          if case_defs
            case_defs.map { |case_args| run_case(args.merge(case_args.symbolize_keys), llm) }
          else
            run_case(args, llm)
          end
        end

        private

        attr_reader :operation

        def run_case(case_args, llm)
          query = case_args[:query].presence || case_args[:input].presence
          raise ArgumentError, "HyDE evals require :query or :input" if query.blank?

          persona = resolve_persona(persona_class: DiscourseAi::Personas::ContentCreator)
          user = Discourse.system_user

          context =
            DiscourseAi::Personas::BotContext.new(
              user: user,
              skip_tool_details: true,
              feature_name: "semantic_search_hyde",
              messages: [{ type: :user, content: query }],
            )

          bot = DiscourseAi::Personas::Bot.as(user, persona: persona, model: llm)
          response = capture_plain_response(bot, context).strip

          wrap_result(response, { query: query })
        end

        def normalize_args(raw_args)
          return {} if raw_args.blank?
          raise ArgumentError, "HyDE evals expect args as a Hash" if !raw_args.is_a?(Hash)

          raw_args.deep_symbolize_keys
        end
      end
    end
  end
end
