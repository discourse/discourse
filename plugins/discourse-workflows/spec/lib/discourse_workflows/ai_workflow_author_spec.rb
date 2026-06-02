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
