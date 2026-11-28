# frozen_string_literal: true

RSpec.describe "Chat message - channel" do
  fab!(:current_user, :user)
  fab!(:channel_1, :chat_channel)
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }

  let(:cdp) { PageObjects::CDP.new }
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  context "when hovering a message" do
    it "activates the message and shows its action buttons" do
      chat_page.visit_channel(channel_1)

      channel_page.hover_message(message_1)

      expect(page).to have_css(
        ".chat-channel[data-id='#{channel_1.id}'] .chat-message-container[data-id='#{message_1.id}'].-active",
      )
      expect(channel_page.messages).to have_actions_container(message_1)
      expect(channel_page.messages).to have_reply_btn(message_1)
      expect(channel_page.messages).to have_reaction_buttons(message_1)
    end

    context "when not following the channel" do
      before { channel_1.membership_for(current_user).update!(following: false) }

      it "does not show the reply or reaction buttons" do
        chat_page.visit_channel(channel_1)

        channel_page.hover_message(message_1)

        expect(channel_page.messages).to have_actions_container(message_1)
        expect(channel_page.messages).to have_no_reply_btn(message_1)
        expect(channel_page.messages).to have_no_reaction_buttons(message_1)
      end
    end
  end

  context "when copying a message" do
    before { cdp.allow_clipboard }

    it "copies the link to the message" do
      chat_page.visit_channel(channel_1)

      channel_page.messages.copy_link(message_1)

      cdp.clipboard_has_text?("/chat/c/-/#{channel_1.id}/#{message_1.id}", strict: false)
      expect(PageObjects::Components::Toasts.new).to have_success(I18n.t("js.chat.link_copied"))
    end

    it "[mobile] copies the text and the link of a single message", mobile: true do
      chat_page.visit_channel(channel_1)

      channel_page.messages.copy_text(message_1)

      cdp.clipboard_has_text?(message_1.message, chomp: true)
      expect(PageObjects::Components::Toasts.new).to have_success(I18n.t("js.chat.text_copied"))

      channel_page.messages.copy_link(message_1)

      cdp.clipboard_has_text?("/chat/c/-/#{channel_1.id}/#{message_1.id}", strict: false)
      expect(PageObjects::Components::Toasts.new).to have_success(I18n.t("js.chat.link_copied"))
    end

    context "when the message is part of a thread" do
      before { channel_1.update!(threading_enabled: true) }

      fab!(:thread_1) do
        Fabricate(
          :chat_thread,
          channel: channel_1,
          original_message_user: current_user,
          with_replies: 1,
        )
      end

      it "copies the link to the message" do
        chat_page.visit_channel(channel_1)

        channel_page.messages.copy_link(thread_1.original_message)

        cdp.clipboard_has_text?(
          "/chat/c/-/#{channel_1.id}/#{thread_1.original_message.id}",
          strict: false,
        )
        expect(PageObjects::Components::Toasts.new).to have_success(I18n.t("js.chat.link_copied"))
      end

      it "[mobile] copies the link to the message", mobile: true do
        chat_page.visit_channel(channel_1)

        channel_page.messages.copy_link(thread_1.original_message)

        cdp.clipboard_has_text?(
          "/chat/c/-/#{channel_1.id}/#{thread_1.original_message.id}",
          strict: false,
        )
        expect(PageObjects::Components::Toasts.new).to have_success(I18n.t("js.chat.link_copied"))
      end
    end
  end
end
