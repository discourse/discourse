# frozen_string_literal: true

describe "Thread list in side panel | full page", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }
  fab!(:other_user) { Fabricate(:user) }

  let(:side_panel_page) { PageObjects::Pages::ChatSidePanel.new }
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:side_panel) { PageObjects::Pages::ChatSidePanel.new }
  let(:thread_page) { PageObjects::Pages::ChatThread.new }
  let(:thread_list_page) { PageObjects::Components::Chat::ThreadList.new }

  before do
    SiteSetting.enable_experimental_chat_threaded_discussions = true
    chat_system_bootstrap(current_user, [channel])
    sign_in(current_user)
  end

  context "when there are no threads that the user is participating in" do
    it "shows a message" do
      chat_page.visit_channel(channel)
      channel_page.open_thread_list
      expect(page).to have_content(I18n.t("js.chat.threads.none"))
    end
  end

  context "for threads the user is not a participant in" do
    fab!(:thread_om) { Fabricate(:chat_message, chat_channel: channel) }

    before { chat_system_user_bootstrap(user: other_user, channel: channel) }

    it "does not show existing threads in the channel if the user is not tracking them" do
      Fabricate(:chat_thread, original_message: thread_om, channel: channel)
      chat_page.visit_channel(channel)
      channel_page.open_thread_list
      expect(page).to have_content(I18n.t("js.chat.threads.none"))
    end

    it "does not show new threads in the channel in the thread list if the user is not tracking them" do
      chat_page.visit_channel(channel)

      using_session(:other_user) do |session|
        sign_in(other_user)
        chat_page.visit_channel(channel)
        channel_page.reply_to(thread_om)
        thread_page.send_message("hey everyone!")
        expect(channel_page).to have_thread_indicator(thread_om)
        session.quit
      end

      channel_page.open_thread_list
      expect(page).to have_content(I18n.t("js.chat.threads.none"))
    end

    describe "when the user creates a new thread" do
      it "does not double up the staged thread and the actual thread in the list" do
        chat_page.visit_channel(channel)
        channel_page.reply_to(thread_om)
        thread_page.send_message("hey everyone!")
        expect(channel_page).to have_thread_indicator(thread_om)
        thread_page.close
        channel_page.open_thread_list
        expect(page).to have_css(
          thread_list_page.item_by_id_selector(thread_om.reload.thread_id),
          count: 1,
        )
      end
    end
  end

  context "when there are threads that the user is participating in" do
    fab!(:thread_1) do
      chat_thread_chain_bootstrap(channel: channel, users: [current_user, other_user])
    end
    fab!(:thread_2) do
      chat_thread_chain_bootstrap(channel: channel, users: [current_user, other_user])
    end

    before do
      chat_system_user_bootstrap(user: other_user, channel: channel)
      thread_1.add(current_user)
      thread_2.add(current_user)
    end

    it "shows a default title for threads without a title" do
      chat_page.visit_channel(channel)
      channel_page.open_thread_list
      expect(page).to have_content(I18n.t("js.chat.thread.default_title", thread_id: thread_1.id))
    end

    it "shows the thread title with emoji" do
      thread_1.update!(title: "What is for dinner? :hamburger:")
      chat_page.visit_channel(channel)
      channel_page.open_thread_list
      expect(thread_list_page.item_by_id(thread_1.id)).to have_content("What is for dinner?")
      expect(thread_list_page.item_by_id(thread_1.id)).to have_css("img.emoji[alt='hamburger']")
    end

    it "shows an excerpt of the original message of the thread" do
      thread_1.original_message.update!(message: "This is a long message for the excerpt")
      thread_1.original_message.rebake!
      chat_page.visit_channel(channel)
      channel_page.open_thread_list
      expect(thread_list_page.item_by_id(thread_1.id)).to have_content(
        "This is a long message for the excerpt",
      )
    end

    it "shows the thread original message user avatar" do
      chat_page.visit_channel(channel)
      channel_page.open_thread_list
      expect(thread_list_page.item_by_id(thread_1.id)).to have_css(
        thread_list_page.avatar_selector(thread_1.original_message.user),
      )
    end

    it "shows the last reply date of the thread" do
      freeze_time
      last_reply = Fabricate(:chat_message, chat_channel: thread_1.channel, thread: thread_1)
      chat_page.visit_channel(channel)
      channel_page.open_thread_list
      expect(thread_list_page.item_by_id(thread_1.id)).to have_css(
        thread_list_page.last_reply_datetime_selector(last_reply),
      )
    end

    it "opens a thread" do
      chat_page.visit_channel(channel)
      channel_page.open_thread_list
      thread_list_page.item_by_id(thread_1.id).click
      expect(side_panel).to have_open_thread(thread_1)
    end

    describe "deleting and restoring the original message of the thread" do
      before do
        thread_1.update!(original_message_user: other_user)
        thread_1.original_message.update!(user: other_user)
      end

      it "hides the thread in the list when another user deletes the original message" do
        chat_page.visit_channel(channel)
        channel_page.open_thread_list
        expect(thread_list_page).to have_thread(thread_1)

        using_session(:tab_2) do |session|
          sign_in(other_user)
          chat_page.visit_thread(thread_1)
          expect(side_panel_page).to have_open_thread(thread_1)
          thread_page.delete_message(thread_1.original_message)
          session.quit
        end

        expect(thread_list_page).to have_no_thread(thread_1)
      end

      it "shows the thread in the list when another user restores the original message" do
        # This is necessary because normal users can't see deleted messages
        other_user.update!(admin: true)
        current_user.update!(admin: true)

        thread_1.original_message.trash!
        chat_page.visit_channel(channel)
        channel_page.open_thread_list
        expect(thread_list_page).to have_no_thread(thread_1)

        using_session(:tab_2) do |session|
          sign_in(other_user)
          chat_page.visit_channel(channel)
          expect(channel_page).to have_no_loading_skeleton
          channel_page.expand_deleted_message(thread_1.original_message)
          channel_page.message_thread_indicator(thread_1.original_message).click
          expect(side_panel_page).to have_open_thread(thread_1)
          thread_page.restore_message(thread_1.original_message)
          session.quit
        end

        expect(thread_list_page).to have_thread(thread_1)
      end
    end

    describe "updating the title of the thread" do
      let(:new_title) { "wow new title" }

      def open_thread_list
        chat_page.visit_channel(channel)
        channel_page.open_thread_list
        expect(side_panel).to have_open_thread_list
      end

      it "allows updating when user is admin" do
        current_user.update!(admin: true)
        open_thread_list
        thread_list_page.item_by_id(thread_1.id).click
        thread_page.header.open_settings
        find(".chat-modal-thread-settings__title-input").fill_in(with: new_title)
        find(".modal-footer .btn-primary").click
        expect(thread_page.header).to have_title_content(new_title)
      end

      it "allows updating when user is same as the chat original message user" do
        thread_1.update!(original_message_user: current_user)
        thread_1.original_message.update!(user: current_user)
        open_thread_list
        thread_list_page.item_by_id(thread_1.id).click
        thread_page.header.open_settings
        find(".chat-modal-thread-settings__title-input").fill_in(with: new_title)
        find(".modal-footer .btn-primary").click
        expect(thread_page.header).to have_title_content(new_title)
      end

      it "does not allow updating if user is neither admin nor original message user" do
        thread_1.update!(original_message_user: other_user)
        thread_1.original_message.update!(user: other_user)

        open_thread_list
        thread_list_page.item_by_id(thread_1.id).click
        expect(thread_page.header).to have_no_settings_button
      end
    end
  end
end
