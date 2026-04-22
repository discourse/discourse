# frozen_string_literal: true

require_relative "base"

module DiscourseAi
  module Evals
    module Runners
      class DataExplorer < Base
        def self.can_handle?(full_feature_name)
          full_feature_name&.start_with?("data_explorer:")
        end

        def run(eval_case, llm, execution_context:)
          args = eval_case.args
          agent = resolve_agent(agent_class: DiscourseDataExplorer::AiQueryGenerator)
          user = Discourse.system_user

          context =
            DiscourseAi::Agents::BotContext.new(
              user: user,
              skip_show_thinking: true,
              feature_name: "evals/data_explorer_query_generation",
              messages: [{ type: :user, content: args[:input] }],
            )

          bot = DiscourseAi::Agents::Bot.as(user, agent: agent, model: llm)
          sql =
            capture_structured_response(
              bot,
              context,
              schema_key: "sql",
              execution_context: execution_context,
            )

          wrap_result(sql.strip, { feature: feature_name })
        end
      end
    end
  end
end
