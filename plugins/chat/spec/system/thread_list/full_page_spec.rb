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
      thread_1.original_message.update!(message: "This is a long message for the excerpt")
      thread_1.original_message.rebake!
      chat_page.visit_channel(channel)
      chat_page.open_thread_list
      expect(thread_list_page.item_by_id(thread_1.id)).to have_content(
        "This is a long message for the excerpt",
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

    context "when the user has unread activity on some thread" do
      let!(:membership) { thread_1.user_chat_thread_memberships.find_by(user: current_user) }

      it "shows an unread indicator over the thread list button in the header" do
        chat_page.visit_channel(channel)
        expect(find(".open-thread-list-btn")).to have_css(".chat-thread-unread-indicator")
      end

      it "shows an unread indicator on the relevant thread list item" do
        chat_page.visit_channel(channel)
        chat_page.open_thread_list
        expect(thread_list_page.item_by_id(thread_1.id)).to have_css(
          ".chat-thread-unread-indicator",
        )
      end

      it "marks the thread as read when opening it and no longer displays the indicator" do
        chat_page.visit_channel(channel)
        chat_page.open_thread_list
        thread_list_page.item_by_id(thread_1.id).click
        expect(find(".open-thread-list-btn")).not_to have_css(".chat-thread-unread-indicator")
      end
    end

    describe "updating the title of the thread" do
      let(:new_title) { "wow new title" }

      def open_thread_list
        chat_page.visit_channel(channel)
        chat_page.open_thread_list
        expect(side_panel).to have_open_thread_list
      end

      it "allows updating when user is admin" do
        current_user.update!(admin: true)
        open_thread_list
        thread_list_page.item_by_id(thread_1.id).find(".chat-thread-list-item__settings").click
        find(".thread-title-input").fill_in(with: new_title)
        find(".modal-footer .btn-primary").click
        expect(thread_list_page.item_by_id(thread_1.id)).to have_content(new_title)
      end

      it "allows updating when user is same as the chat original message user" do
        thread_1.update!(original_message_user: current_user)
        thread_1.original_message.update!(user: current_user)
        open_thread_list
        thread_list_page.item_by_id(thread_1.id).find(".chat-thread-list-item__settings").click
        find(".thread-title-input").fill_in(with: new_title)
        find(".modal-footer .btn-primary").click
        expect(thread_list_page.item_by_id(thread_1.id)).to have_content(new_title)
      end

      it "does not allow updating if user is neither admin nor original message user" do
        thread_1.update!(original_message_user: other_user)
        thread_1.original_message.update!(user: other_user)
        open_thread_list
        expect(
          thread_list_page.item_by_id(thread_1.id).find(".chat-thread-list-item__settings")[
            :disabled
          ],
        ).to eq("true")
      end
    end
  end
end
