# frozen_string_literal: true

RSpec.describe "Chat | composer | channel", type: :system, js: true do
  fab!(:channel_1) { Fabricate(:chat_channel) }
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }
  fab!(:current_user) { Fabricate(:admin) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:thread_page) { PageObjects::Pages::ChatThread.new }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  describe "reply to message" do
    it "renders text in the details" do
      message_1.update!(message: "<mark>not marked</mark>")
      message_1.rebake!
      chat_page.visit_channel(channel_1)
      channel_page.reply_to(message_1)

      expect(channel_page.composer.message_details).to have_message(
        id: message_1.id,
        exact_text: "<mark>not marked</mark>",
      )
    end

    context "when threading is disabled" do
      it "replies to the message" do
        chat_page.visit_channel(channel_1)
        channel_page.reply_to(message_1)

        expect(channel_page.composer.message_details).to be_replying_to(message_1)
      end
    end

    context "when threading is enabled" do
      before do
        SiteSetting.enable_experimental_chat_threaded_discussions = true
        channel_1.update!(threading_enabled: true)
      end

      it "replies in the thread" do
        chat_page.visit_channel(channel_1)
        channel_page.reply_to(message_1)

        expect(thread_page.composer).to be_focused
      end
    end
  end

  describe "edit message" do
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1, user: current_user) }

    it "adds the edit indicator" do
      chat_page.visit_channel(channel_1)
      channel_page.edit_message(message_1)

      expect(channel_page.composer).to be_editing_message(message_1)
    end

    it "updates the message instantly" do
      chat_page.visit_channel(channel_1)
      page.driver.browser.network_conditions = { offline: true }
      channel_page.edit_message(message_1, "instant")

      expect(channel_page.messages).to have_message(
        text: message_1.message + "instant",
        persisted: false,
      )
    ensure
      page.driver.browser.network_conditions = { offline: false }
    end

    context "when pressing escape" do
      it "cancels editing" do
        chat_page.visit_channel(channel_1)
        channel_page.edit_message(message_1)
        channel_page.composer.cancel_shortcut

        expect(channel_page.composer).to be_editing_no_message
        expect(channel_page.composer.value).to eq("")
      end
    end

    context "when closing edited message" do
      it "cancels editing" do
        chat_page.visit_channel(channel_1)
        channel_page.edit_message(message_1)
        channel_page.composer.cancel_editing

        expect(channel_page.composer).to be_editing_no_message
        expect(channel_page.composer.value).to eq("")
      end
    end
  end
end
