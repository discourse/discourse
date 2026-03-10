# frozen_string_literal: true

require_relative "base"

module DiscourseAi
  module Evals
    module Runners
      class Hyde < Base
        def self.can_handle?(feature_name)
          feature_name&.start_with?("embeddings:hyde")
        end

        def run(eval_case, llm, execution_context:)
          args = normalize_args(eval_case.args)
          case_defs = Array(args.delete(:cases)).presence

          if case_defs
            case_defs.map do |case_args|
              run_case(args.merge(case_args.symbolize_keys), llm, execution_context:)
            end
          else
            run_case(args, llm, execution_context:)
          end
        end

        private

        def run_case(case_args, llm, execution_context:)
          query = case_args[:query].presence || case_args[:input].presence
          raise ArgumentError, "HyDE evals require :query or :input" if query.blank?

          agent = resolve_agent(agent_class: DiscourseAi::Agents::ContentCreator)
          user = Discourse.system_user

          context =
            DiscourseAi::Agents::BotContext.new(
              user: user,
              skip_show_thinking: true,
              feature_name: "semantic_search_hyde",
              messages: [{ type: :user, content: query }],
            )

          bot = DiscourseAi::Agents::Bot.as(user, agent: agent, model: llm)
          response = capture_plain_response(bot, context, execution_context:).strip

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
