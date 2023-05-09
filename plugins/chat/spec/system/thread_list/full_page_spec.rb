# frozen_string_literal: true

describe "Thread list in side panel | full page", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }
  fab!(:other_user) { Fabricate(:user) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:side_panel) { PageObjects::Pages::ChatSidePanel.new }
  let(:thread_page) { PageObjects::Pages::ChatThread.new }
  let(:thread_list_page) { PageObjects::Pages::ChatThreadList.new }

  before do
    SiteSetting.enable_experimental_chat_threaded_discussions = true
    chat_system_bootstrap(current_user, [channel])
    sign_in(current_user)
  end

  context "when there are no threads that the user is participating in" do
    it "shows a message" do
      chat_page.visit_channel(channel)
      chat_page.open_thread_list
      expect(page).to have_content(I18n.t("js.chat.threads.none"))
    end
  end

  context "when there are threads that the user is participating in" do
    before { chat_system_user_bootstrap(user: other_user, channel: channel) }

    fab!(:thread_1) do
      chat_thread_chain_bootstrap(channel: channel, users: [current_user, other_user])
    end
    fab!(:thread_2) do
      chat_thread_chain_bootstrap(channel: channel, users: [current_user, other_user])
    end

    it "shows a default title for threads without a title" do
      chat_page.visit_channel(channel)
      chat_page.open_thread_list
      expect(page).to have_content(I18n.t("js.chat.thread.default_title", thread_id: thread_1.id))
    end

    it "shows the thread title with emoji" do
      thread_1.update!(title: "What is for dinner? :hamburger:")
      chat_page.visit_channel(channel)
      chat_page.open_thread_list
      expect(thread_list_page.item_by_id(thread_1.id)).to have_content("What is for dinner?")
      expect(thread_list_page.item_by_id(thread_1.id)).to have_css("img.emoji[alt='hamburger']")
    end

    it "shows an excerpt of the original message of the thread" do
      chat_page.visit_channel(channel)
      chat_page.open_thread_list
      expect(thread_list_page.item_by_id(thread_1.id)).to have_content(
        thread_1.excerpt.gsub("&hellip;", "…"),
      )
    end

    it "shows the thread original message user username and avatar" do
      chat_page.visit_channel(channel)
      chat_page.open_thread_list
      expect(thread_list_page.item_by_id(thread_1.id)).to have_css(
        ".chat-thread-original-message__avatar .chat-user-avatar .chat-user-avatar-container img",
      )
      expect(
        thread_list_page.item_by_id(thread_1.id).find(".chat-thread-original-message__username"),
      ).to have_content(thread_1.original_message.user.username)
    end

    it "opens a thread" do
      chat_page.visit_channel(channel)
      chat_page.open_thread_list
      thread_list_page.item_by_id(thread_1.id).click
      expect(side_panel).to have_open_thread(thread_1)
    end
  end
end
