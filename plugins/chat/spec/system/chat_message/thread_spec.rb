# frozen_string_literal: true

RSpec.describe "Chat message - thread", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:chat_channel, threading_enabled: true) }
  fab!(:thread_original_message) { Fabricate(:chat_message_with_service, chat_channel: channel_1) }
  fab!(:thread_message_1) do
    Fabricate(
      :chat_message_with_service,
      chat_channel: channel_1,
      in_reply_to: thread_original_message,
    )
  end

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:thread_page) { PageObjects::Pages::ChatThread.new }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  context "when hovering a message" do
    it "adds an active class" do
      chat_page.visit_thread(thread_message_1.thread)

      thread_page.hover_message(thread_message_1)

      expect(page).to have_css(
        ".chat-thread[data-id='#{thread_message_1.thread.id}'] [data-id='#{thread_message_1.id}'].chat-message-container.-active",
      )
    end
  end

  context "when copying text of a message" do
    let(:cdp) { PageObjects::CDP.new }

    before { cdp.allow_clipboard }

    it "[mobile] copies the text of a single message", mobile: true do
      chat_page.visit_thread(thread_message_1.thread)

      thread_page.messages.copy_text(thread_message_1)

      cdp.clipboard_has_text?(thread_message_1.message)
      expect(PageObjects::Components::Toasts.new).to have_success(I18n.t("js.chat.text_copied"))
    end
  end

  context "when copying link to a message" do
    let(:cdp) { PageObjects::CDP.new }

    before { cdp.allow_clipboard }

    it "copies the link to the thread" do
      chat_page.visit_thread(thread_message_1.thread)

      thread_page.messages.copy_link(thread_message_1)

      cdp.clipboard_has_text?(
        "/chat/c/-/#{channel_1.id}/t/#{thread_message_1.thread.id}/#{thread_message_1.id}",
        strict: false,
      )
      expect(PageObjects::Components::Toasts.new).to have_success(I18n.t("js.chat.link_copied"))
    end

    it "[mobile] copies the link to the thread", mobile: true do
      chat_page.visit_thread(thread_message_1.thread)

      thread_page.messages.copy_link(thread_message_1)

      cdp.clipboard_has_text?(
        "/chat/c/-/#{channel_1.id}/t/#{thread_message_1.thread.id}/#{thread_message_1.id}",
        strict: false,
      )
      expect(PageObjects::Components::Toasts.new).to have_success(I18n.t("js.chat.link_copied"))
    end
  end
end
