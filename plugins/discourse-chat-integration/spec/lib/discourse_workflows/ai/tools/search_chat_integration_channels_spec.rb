# frozen_string_literal: true

require_relative "../../../../dummy_provider"

RSpec.describe DiscourseWorkflows::Ai::Tools::SearchChatIntegrationChannels do
  include_context "with validated dummy provider"

  fab!(:admin)

  let(:channel) do
    DiscourseChatIntegration::Channel.create!(provider: "dummy2", data: { "val" => "#alerts" })
  end

  before do
    SiteSetting.enable_discourse_workflows = true
    SiteSetting.chat_integration_enabled = true
    SiteSetting.other_dummy_provider_enabled = true
  end

  def invoke_tool(query:)
    context = DiscourseAi::Agents::BotContext.new(messages: [], user: admin)
    described_class.new(
      { query: query },
      bot_user: Discourse.system_user,
      llm: nil,
      context: context,
    ).invoke
  end

  it "searches enabled external channels by provider or channel label" do
    channel # force creation before searching

    result = invoke_tool(query: "#aler")

    expect(result).to include(status: "success", query: "aler")
    expect(result[:matches]).to contain_exactly(
      { id: channel.id, name: "dummy2: #alerts", provider: "dummy2" },
    )
  end

  it "excludes channels for disabled providers" do
    channel # force creation before disabling the provider
    SiteSetting.other_dummy_provider_enabled = false

    expect(invoke_tool(query: "dummy2")[:matches]).to be_empty
  end
end
