# frozen_string_literal: true

RSpec.describe "Chat | composer | channel", type: :system do
  fab!(:channel_1) { Fabricate(:chat_channel) }
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }
  fab!(:current_user) { Fabricate(:admin) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:thread_page) { PageObjects::Pages::ChatThread.new }
  let(:cdp) { PageObjects::CDP.new }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  describe "reply to message" do
    context "when raw contains html" do
      fab!(:message_1) do
        Fabricate(
          :chat_message,
          use_service: true,
          chat_channel: channel_1,
          message: "<abbr>abbr</abbr>",
        )
      end

      it "renders text in the details" do
        chat_page.visit_channel(channel_1)

        channel_page.reply_to(message_1)

        expect(channel_page.composer.message_details).to have_message(
          id: message_1.id,
          exact_text: "<abbr>abbr</abbr>",
        )
      end
    end

    context "when threading is disabled" do
      it "replies to the message" do
        chat_page.visit_channel(channel_1)
        channel_page.reply_to(message_1)

        expect(channel_page.composer.message_details).to be_replying_to(message_1)
      end
    end

    context "when threading is enabled" do
      before { channel_1.update!(threading_enabled: true) }

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

      cdp.with_network_disconnected do
        channel_page.edit_message(message_1, "instant")

        expect(channel_page.messages).to have_message(
          text: message_1.message + " instant",
          persisted: false,
        )
      end
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

  context "when click on reply indicator" do
    before do
      Fabricate(:chat_message, chat_channel: channel_1)
      Fabricate(:chat_message, chat_channel: channel_1, in_reply_to: message_1)
    end

    it "highlights the message" do
      chat_page.visit_channel(channel_1)

      page.find(".chat-reply").click

      expect(channel_page.messages).to have_message(id: message_1.id, highlighted: true)
    end
  end
end
