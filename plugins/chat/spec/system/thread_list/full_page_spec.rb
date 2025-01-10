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
    fab!(:thread_om) { Fabricate(:chat_message, chat_channel: channel, use_service: true) }

    before { chat_system_user_bootstrap(user: other_user, channel: channel) }

    it "it shows threads in the channel even if the user is not tracking them" do
      thread_1 =
        Fabricate(
          :chat_thread,
          original_message: thread_om,
          channel: channel,
          with_replies: 1,
          use_service: true,
        )
      chat_page.visit_channel(channel)
      channel_page.open_thread_list

      expect(thread_list_page).to have_thread(thread_1)
    end

    describe "when the user creates a new thread" do
      it "does not double up the staged thread and the actual thread in the list" do
        chat_page.visit_channel(channel)
        channel_page.reply_to(thread_om)
        thread_page.send_message
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

  it "doesn’t list threads with no replies" do
    thread = Fabricate(:chat_thread, channel: channel, use_service: true)

    chat_page.visit_channel(channel)
    channel_page.open_thread_list

    expect(thread_list_page).to have_no_thread(thread)
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

    it "shows the OM excerpt for threads without a title" do
      chat_page.visit_threads_list(channel)

      expect(page).to have_content(thread_1.original_message.excerpt)
    end

    it "shows the thread title with emoji" do
      thread_1.update!(title: "What is for dinner? :hamburger:")
      chat_page.visit_threads_list(channel)

      expect(thread_list_page.item_by_id(thread_1.id)).to have_content("What is for dinner?")
      expect(thread_list_page.item_by_id(thread_1.id)).to have_css("img.emoji[alt='hamburger']")
    end

    it "shows an excerpt of the original message of the thread", inline: true do
      update_message!(
        thread_1.original_message,
        user: thread_1.original_message.user,
        text: "This is a long message for the excerpt",
      )
      chat_page.visit_threads_list(channel)

      expect(thread_list_page.item_by_id(thread_1.id)).to have_content(
        "This is a long message for the excerpt",
      )
    end

    it "builds an excerpt for the original message if it doesn’t have one" do
      thread_1.original_message.update!(excerpt: nil)
      chat_page.visit_threads_list(channel)

      expect(thread_list_page.item_by_id(thread_1.id)).to have_content(
        thread_1.original_message.build_excerpt,
      )
    end

    it "doesn’t show the thread original message user avatar" do
      chat_page.visit_threads_list(channel)

      expect(thread_list_page.item_by_id(thread_1.id)).to have_no_css(
        thread_list_page.avatar_selector(thread_1.original_message.user),
      )
    end

    it "shows the last reply date of the thread" do
      freeze_time
      last_reply = Fabricate(:chat_message, thread: thread_1, use_service: true)
      chat_page.visit_threads_list(channel)

      expect(thread_list_page.item_by_id(thread_1.id)).to have_css(
        thread_list_page.last_reply_datetime_selector(last_reply),
      )
    end

    it "shows participants" do
      chat_page.visit_threads_list(channel)

      expect(thread_list_page.item_by_id(thread_1.id)).to have_css(
        ".avatar[title='#{current_user.username}']",
      )
      expect(thread_list_page.item_by_id(thread_1.id)).to have_css(
        ".avatar[title='#{other_user.username}']",
      )
    end

    it "opens a thread" do
      chat_page.visit_threads_list(channel)

      thread_list_page.item_by_id(thread_1.id).click
      expect(side_panel).to have_open_thread(thread_1)
    end

    describe "deleting and restoring the original message of the thread" do
      fab!(:thread_1) do
        chat_thread_chain_bootstrap(
          channel: channel,
          messages_count: 2,
          users: [current_user, other_user],
        )
      end

      before do
        thread_1.update!(original_message_user: other_user)
        thread_1.original_message.update!(user: other_user)
      end

      it "hides the thread in the list when another user deletes the original message" do
        chat_page.visit_threads_list(channel)

        expect(thread_list_page).to have_thread(thread_1)

        trash_message!(thread_1.original_message, user: other_user)

        expect(thread_list_page).to have_no_thread(thread_1)
      end

      it "shows the thread in the list when another user restores the original message" do
        trash_message!(thread_1.original_message)
        chat_page.visit_threads_list(channel)

        expect(thread_list_page).to have_no_thread(thread_1)

        restore_message!(thread_1.original_message, user: other_user)

        expect(thread_list_page).to have_thread(thread_1)
      end
    end

    describe "updating the title of the thread" do
      let(:new_title) { "wow new title" }

      it "allows updating when user is admin" do
        current_user.update!(admin: true)
        chat_page.visit_threads_list(channel)
        thread_list_page.item_by_id(thread_1.id).click
        thread_page.header.open_settings
        find(".chat-modal-thread-settings__title-input").fill_in(with: new_title)
        find(".d-modal__footer .btn-primary").click

        expect(thread_page.header).to have_title_content(new_title)
      end

      it "allows updating when user is same as the chat original message user" do
        thread_1.update!(original_message_user: current_user)
        thread_1.original_message.update!(user: current_user)
        chat_page.visit_threads_list(channel)
        thread_list_page.item_by_id(thread_1.id).click
        thread_page.header.open_settings
        find(".chat-modal-thread-settings__title-input").fill_in(with: new_title)
        find(".d-modal__footer .btn-primary").click

        expect(thread_page.header).to have_title_content(new_title)
      end

      it "does not allow updating if user is neither admin nor original message user" do
        thread_1.update!(original_message_user: other_user)
        thread_1.original_message.update!(user: other_user)
        chat_page.visit_threads_list(channel)
        thread_list_page.item_by_id(thread_1.id).click

        expect(thread_page.header).to have_no_settings_button
      end
    end
  end
end
