# frozen_string_literal: true

RSpec.describe "Channel message selection", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:chat_channel) }
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }
  fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel_1) }
  fab!(:message_3) { Fabricate(:chat_message, chat_channel: channel_1) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:thread_page) { PageObjects::Pages::ChatThread.new }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  it "can select multiple messages" do
    chat_page.visit_channel(channel_1)
    channel_page.select_message(message_1)

    expect(page).to have_css(".chat-selection-management")

    channel_page.message_by_id(message_2.id).find(".chat-message-selector").click
    expect(page).to have_css(".chat-message-selector:checked", count: 2)
  end

  it "can shift + click to select messages between the first and last" do
    chat_page.visit_channel(channel_1)
    channel_page.select_message(message_1)

    expect(page).to have_css(".chat-selection-management")

    channel_page.message_by_id(message_3.id).find(".chat-message-selector").click(:shift)
    expect(page).to have_css(".chat-message-selector:checked", count: 3)
  end

  context "when visiting another channel" do
    fab!(:channel_2) { Fabricate(:chat_channel) }

    before { channel_2.add(current_user) }

    it "resets message selection" do
      chat_page.visit_channel(channel_1)
      channel_page.select_message(message_1)

      expect(page).to have_css(".chat-selection-management")

      chat_page.visit_channel(channel_2)

      expect(page).to have_no_css(".chat-selection-management")
    end
  end

  context "when in a thread" do
    fab!(:thread_message_1) do
      Chat::MessageCreator.create(
        chat_channel: channel_1,
        in_reply_to_id: message_1.id,
        user: Fabricate(:user),
        content: Faker::Lorem.paragraph,
      ).chat_message
    end

    fab!(:thread_message_2) do
      Chat::MessageCreator.create(
        chat_channel: channel_1,
        in_reply_to_id: message_1.id,
        user: Fabricate(:user),
        content: Faker::Lorem.paragraph,
      ).chat_message
    end

    fab!(:thread_message_3) do
      Chat::MessageCreator.create(
        chat_channel: channel_1,
        in_reply_to_id: message_1.id,
        user: Fabricate(:user),
        content: Faker::Lorem.paragraph,
      ).chat_message
    end

    before do
      SiteSetting.enable_experimental_chat_threaded_discussions = true
      channel_1.update!(threading_enabled: true)
    end

    it "can select multiple messages" do
      chat_page.visit_thread(thread_message_1.thread)
      thread_page.select_message(thread_message_1)

      expect(thread_page).to have_css(".chat-selection-management")

      thread_page.message_by_id(thread_message_2.id).find(".chat-message-selector").click

      expect(thread_page).to have_css(".chat-message-selector:checked", count: 2)
    end

    it "can shift + click to select messages between the first and last" do
      chat_page.visit_thread(thread_message_1.thread)
      thread_page.select_message(thread_message_1)

      expect(thread_page).to have_css(".chat-selection-management")

      thread_page.message_by_id(thread_message_3.id).find(".chat-message-selector").click(:shift)

      expect(page).to have_css(".chat-message-selector:checked", count: 3)
    end
  end
end
