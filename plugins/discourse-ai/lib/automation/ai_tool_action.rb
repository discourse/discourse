# frozen_string_literal: true

module DiscourseAi
  module Automation
    module AiToolAction
      def self.handle(post:, tool_id:, llm_model_id: nil, automation: nil)
        tool = ::AiTool.find_by(id: tool_id)
        return if !tool || !tool.enabled

        # Build LLM if specified (for tools that call llm.generate())
        llm = nil
        if llm_model_id.present?
          llm_model = LlmModel.find_by(id: llm_model_id)
          llm = DiscourseAi::Completions::Llm.proxy(llm_model) if llm_model
        end

        # Build context - tool accesses post/topic/user via context object
        context =
          DiscourseAi::Personas::BotContext.new(
            post: post,
            feature_name: "ai_tool_action",
            feature_context: {
              automation_id: automation&.id,
              automation_name: automation&.name,
            },
          )

        runner = tool.runner({}, llm: llm, bot_user: Discourse.system_user, context: context)
        runner.invoke
      end
    end
  end
end
