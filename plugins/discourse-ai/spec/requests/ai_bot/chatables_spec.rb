# frozen_string_literal: true

RSpec.describe Chat::Api::ChatablesController do
  fab!(:group)
  fab!(:member, :user)
  fab!(:non_member, :user)
  fab!(:agent_bot) { Fabricate(:bot, username: "tour_agent_bot", interactive_bot: true) }
  fab!(:generic_bot) { Fabricate(:bot, username: "tour_generic_bot", interactive_bot: true) }
  fab!(:agent) do
    Fabricate(
      :ai_agent,
      user: agent_bot,
      allowed_group_ids: [group.id],
      allow_chat_direct_messages: true,
    )
  end

  before do
    enable_current_plugin
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:everyone]
    group.add(member)
  end

  def search_for_bots
    get "/chat/api/chatables", params: { term: "tour_", include_direct_message_channels: false }
    expect(response.status).to eq(200)
    response.parsed_body.fetch("users").pluck("identifier")
  end

  it "keeps interactive agents restricted to their allowed groups in the Chat picker" do
    sign_in(non_member)
    expect(search_for_bots).to contain_exactly("u-#{generic_bot.id}")

    sign_in(member)
    expect(search_for_bots).to contain_exactly("u-#{generic_bot.id}", "u-#{agent_bot.id}")
  end

  it "does not list an interactive agent without a Chat modality" do
    agent.update!(allow_chat_direct_messages: false, allow_chat_channel_mentions: false)
    sign_in(member)

    expect(search_for_bots).to contain_exactly("u-#{generic_bot.id}")
  end
end
