# frozen_string_literal: true

RSpec.describe "Summarize a channel since your last visit", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:group) { Fabricate(:group) }
  let(:plugin) { Plugin::Instance.new }

  fab!(:channel) { Fabricate(:chat_channel) }

  fab!(:message_1) { Fabricate(:chat_message, created_at: 4.minute.ago, chat_channel: channel) }
  fab!(:message_2) { Fabricate(:chat_message, created_at: 3.minute.ago, chat_channel: channel) }

  let(:chat) { PageObjects::Pages::Chat.new }

  fab!(:membership) do
    Fabricate(
      :user_chat_channel_membership,
      chat_channel: channel,
      user: current_user,
      last_read_message_id: message_1.id,
    )
  end

  before do
    group.add(current_user)

    strategy = DummyCustomSummarization.new("dummy")
    plugin.register_summarization_strategy(strategy)
    SiteSetting.summarization_strategy = strategy.model
    SiteSetting.custom_summarization_allowed_groups = group.id.to_s

    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = group.id.to_s
    sign_in(current_user)
  end

  it "displays a summary of the messages since last visit" do
    chat.visit_channel(channel)

    find(".chat-message-separator__button-summarize").click

    expect(page.has_css?(".since-last-visit-summary-modal", wait: 5)).to eq(true)

    expect(find(".summary-area").text).to eq(DummyCustomSummarization::RESPONSE)
  end
end
