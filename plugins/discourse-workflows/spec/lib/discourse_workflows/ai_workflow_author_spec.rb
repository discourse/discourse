# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::AiWorkflowAuthor do
  before { SiteSetting.tagging_enabled = true }

  it "includes workflow authoring and safe forum discovery tools" do
    expect(described_class.new.tools).to include(
      DiscourseAi::Agents::Tools::ListCategories,
      DiscourseAi::Agents::Tools::ListTags,
      DiscourseAi::Agents::Tools::Search,
      DiscourseAi::Agents::Tools::Read,
      DiscourseAi::Agents::Tools::Time,
      DiscourseWorkflows::Ai::Tools::WorkflowNodeCatalog,
      DiscourseWorkflows::Ai::Tools::WorkflowGraphContext,
      DiscourseWorkflows::Ai::Tools::WorkflowValidatePatch,
      DiscourseWorkflows::Ai::Tools::WorkflowScriptContext,
      DiscourseWorkflows::Ai::Tools::WorkflowValidateScript,
      DiscourseWorkflows::Ai::Tools::WorkflowAiAgentCatalog,
      DiscourseWorkflows::Ai::Tools::WorkflowAuthoringResult,
    )
  end

  it "requires the final authoring result tool" do
    author = described_class.new

    expect(author.response_format).to be_nil
    expect(author.system_prompt).to include(
      "Do not write a final prose, markdown, or JSON answer",
      "call workflow_authoring_result exactly once",
      "Use workflow_ai_agent_catalog before adding action:ai_agent nodes",
      "parameters.runner_username",
      "parameters.upload_ids",
      "Use search_chat_channels before asking the admin to choose a chat channel",
      "call workflow_validate_script with the exact mode and code",
      "Do not add a Code node only to copy trigger fields forward",
      "create_ai_agent",
    )
  end

  it "includes chat channel search only when chat is enabled" do
    skip "Chat plugin is not available" if !defined?(::Chat::Channel)

    SiteSetting.chat_enabled = false
    expect(described_class.new.tools).not_to include(
      DiscourseWorkflows::Ai::Tools::SearchChatChannels,
    )

    SiteSetting.chat_enabled = true
    expect(described_class.new.tools).to include(DiscourseWorkflows::Ai::Tools::SearchChatChannels)
  end
end
