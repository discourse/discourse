# frozen_string_literal: true

module DiscourseWorkflowsAiToolHelpers
  def build_ai_tool(tool_class, params, user:, agent_options: {})
    tool_class.new(
      params,
      agent_options:,
      bot_user: Discourse.system_user,
      llm: nil,
      context: DiscourseAi::Agents::BotContext.new(messages: [], user:),
    )
  end

  def invoke_ai_tool(tool_class, params, user:, agent_options: {})
    build_ai_tool(tool_class, params, user:, agent_options:).invoke
  end
end

RSpec.configure { |config| config.include(DiscourseWorkflowsAiToolHelpers) }
