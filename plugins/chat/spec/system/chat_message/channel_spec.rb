# frozen_string_literal: true

RSpec.describe "Chat message - channel", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:chat_channel) }
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1, use_service: true) }

  let(:cdp) { PageObjects::CDP.new }
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  context "when hovering a message" do
    it "adds an active class" do
      chat_page.visit_channel(channel_1)

      channel_page.hover_message(message_1)

      expect(page).to have_css(
        ".chat-channel[data-id='#{channel_1.id}'] .chat-message-container[data-id='#{message_1.id}'].-active",
      )
    end
  end

  context "when copying text of a message" do
    before { cdp.allow_clipboard }

    it "[mobile] copies the text of a single message", mobile: true do
      chat_page.visit_channel(channel_1)

      channel_page.messages.copy_text(message_1)

      cdp.clipboard_has_text?(message_1.message, chomp: true)
      expect(PageObjects::Components::Toasts.new).to have_success(I18n.t("js.chat.text_copied"))
    end
  end

  context "when copying link to a message" do
    before { cdp.allow_clipboard }

    it "copies the link to the message" do
      chat_page.visit_channel(channel_1)

      channel_page.messages.copy_link(message_1)

      cdp.clipboard_has_text?("/chat/c/-/#{channel_1.id}/#{message_1.id}", strict: false)
      expect(PageObjects::Components::Toasts.new).to have_success(I18n.t("js.chat.link_copied"))
    end

    it "[mobile] copies the link to the message", mobile: true do
      chat_page.visit_channel(channel_1)

      channel_page.messages.copy_link(message_1)

      cdp.clipboard_has_text?("/chat/c/-/#{channel_1.id}/#{message_1.id}", strict: false)
      expect(PageObjects::Components::Toasts.new).to have_success(I18n.t("js.chat.link_copied"))
    end

    context "when the message is part of a thread" do
      before { channel_1.update!(threading_enabled: true) }

      fab!(:thread_1) do
        chat_thread_chain_bootstrap(
          channel: channel_1,
          users: [current_user, Fabricate(:user)],
          messages_count: 2,
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
