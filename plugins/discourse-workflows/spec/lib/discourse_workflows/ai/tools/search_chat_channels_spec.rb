# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Ai::Tools::SearchChatChannels do
  fab!(:admin)

  before { SiteSetting.chat_enabled = true if defined?(SiteSetting.chat_enabled) }

  def invoke_tool(query:)
    context = DiscourseAi::Agents::BotContext.new(messages: [], user: admin)
    described_class.new(
      { query: query },
      bot_user: Discourse.system_user,
      llm: nil,
      context: context,
    ).invoke
  end

  it "searches open public chat channels by partial hashtag name" do
    skip "Chat plugin is not available" if !defined?(::Chat::Channel)

    category = Fabricate(:category, name: "General", slug: "general")
    channel = Fabricate(:category_channel, chatable: category, name: "general")

    result = invoke_tool(query: "#genera")

    expect(result).to include(status: "success", query: "genera")
    expect(result[:matches]).to contain_exactly(
      {
        id: channel.id,
        name: "general",
        slug: channel.slug,
        category_id: category.id,
        category_name: "General",
        category_slug: "general",
        url: channel.relative_url,
      },
    )
  end

  it "does not return non-selectable channels" do
    skip "Chat plugin is not available" if !defined?(::Chat::Channel)

    open_channel = Fabricate(:category_channel, name: "general")
    Fabricate(:category_channel, name: "general closed", status: :closed)
    Fabricate(:direct_message_channel, name: nil)

    result = invoke_tool(query: "general")

    expect(result[:matches].map { |match| match[:id] }).to contain_exactly(open_channel.id)
  end
end
