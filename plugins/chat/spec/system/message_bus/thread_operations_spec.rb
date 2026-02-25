# frozen_string_literal: true

RSpec.describe "Chat MessageBus | thread-level operations", type: :system do
  fab!(:current_user, :user)
  fab!(:other_user, :user)
  fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }
  fab!(:thread) { Fabricate(:chat_thread, channel: channel) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:side_panel) { PageObjects::Pages::ChatSidePanel.new }
  let(:thread_page) { PageObjects::Pages::ChatThread.new }

  before do
    chat_system_bootstrap(current_user, [channel])
    channel.add(other_user)
    thread.add(current_user)
    thread.add(other_user)
  end

  describe "reaction in thread" do
    fab!(:thread_message) do
      Fabricate(:chat_message, chat_channel: channel, thread: thread, user: current_user)
    end

    it "updates reaction count when another user reacts" do
      sign_in(current_user)
      chat_page.visit_thread(thread)
      expect(side_panel).to have_open_thread(thread)

      Chat::MessageReactor.new(other_user, channel).react!(
        message_id: thread_message.id,
        react_action: :add,
        emoji: "heart",
      )

      expect(thread_page).to have_reaction(thread_message, "heart")
    end
  end

  describe "edit in thread" do
    fab!(:thread_message) do
      Fabricate(:chat_message, chat_channel: channel, thread: thread, user: other_user)
    end

    it "updates content when another user edits a message" do
      sign_in(current_user)
      chat_page.visit_thread(thread)
      expect(side_panel).to have_open_thread(thread)

      using_session(:other_user) do
        sign_in(other_user)
        chat_page.visit_thread(thread)
        thread_page.edit_message(thread_message, "edited content")
        expect(page).to have_content(I18n.t("js.chat.edited"))
      end

      expect(page).to have_content(I18n.t("js.chat.edited"))
    end
  end

  describe "delete in thread" do
    fab!(:thread_message) do
      Fabricate(:chat_message, chat_channel: channel, thread: thread, user: other_user)
    end

    context "when current user is admin" do
      fab!(:current_user, :admin)

      it "shows deleted message when another user's message is deleted" do
        sign_in(current_user)
        chat_page.visit_thread(thread)
        expect(side_panel).to have_open_thread(thread)

        thread_page.messages.delete(thread_message)

        expect(thread_page.messages).to have_deleted_message(thread_message, count: 1)
      end
    end
  end

  describe "self_flagged in thread" do
    fab!(:thread_message) do
      Fabricate(:chat_message, chat_channel: channel, thread: thread, user: other_user)
    end

    it "shows flag icon after flagging a message in thread" do
      sign_in(current_user)
      chat_page.visit_thread(thread)
      expect(side_panel).to have_open_thread(thread)

      thread_page.messages.flag(thread_message)

      expect(page).to have_css(".flag-modal")

      choose("radio_spam")
      click_button(I18n.t("js.chat.flagging.action"))

      expect(thread_page.message_by_id(thread_message.id)).to have_css(".chat-message-info__flag")
    end
  end

  describe "flag in thread" do
    fab!(:staff_user, :admin)
    fab!(:thread_message) do
      Fabricate(:chat_message, chat_channel: channel, thread: thread, user: other_user)
    end

    before { channel.add(staff_user) }

    it "staff user receives reviewable after flag in thread" do
      sign_in(staff_user)
      chat_page.visit_thread(thread)
      expect(side_panel).to have_open_thread(thread)

      using_session(:flagger) do
        sign_in(current_user)
        chat_page.visit_thread(thread)
        thread_page.messages.flag(thread_message)
        expect(page).to have_css(".flag-modal")
        choose("radio_spam")
        click_button(I18n.t("js.chat.flagging.action"))
      end

      expect(thread_page.message_by_id(thread_message.id)).to have_css(".chat-message-info__flag")
    end
  end
end
