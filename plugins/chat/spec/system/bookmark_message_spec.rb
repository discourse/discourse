# frozen_string_literal: true

RSpec.describe "Bookmark message" do
  fab!(:current_user, :user)

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:thread_page) { PageObjects::Pages::ChatThread.new }
  let(:bookmark_modal) { PageObjects::Modals::Bookmark.new }
  let(:user_menu) { PageObjects::Components::UserMenu.new }

  fab!(:category_channel_1, :category_channel)
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: category_channel_1) }

  before do
    chat_system_bootstrap
    category_channel_1.add(current_user)
    sign_in(current_user)
  end

  context "when desktop" do
    context "when in a long thread" do
      fab!(:category_channel_1) { Fabricate(:category_channel, threading_enabled: true) }
      fab!(:thread) do
        Fabricate(:chat_thread, channel: category_channel_1, original_message_user: current_user)
      end
      fab!(:first_reply) do
        Fabricate(:chat_message, chat_channel: category_channel_1, user: current_user, thread:)
      end
      fab!(:last_reply) do
        # Seed a full page of history, but don't send each historical reply live.
        replies =
          Fabricate.times(
            49,
            :chat_message,
            chat_channel: category_channel_1,
            user: current_user,
            thread: thread,
          )
        category_channel_1.update!(last_message: thread.original_message)
        thread.update_last_message_id!
        thread.update!(replies_count: replies.size + 1)
        replies.last
      end

      it "supports linking to a bookmark in a long thread" do
        thread.membership_for(current_user).update!(last_read_message_id: last_reply.id)
        bookmark = Bookmark.create!(bookmarkable: first_reply, user: current_user)

        visit bookmark.bookmarkable.url

        expect(thread_page).to have_bookmarked_message(first_reply)
      end
    end

    context "in drawer mode" do
      fab!(:category_channel_2, :category_channel)
      fab!(:message_2) { Fabricate(:chat_message, chat_channel: category_channel_2) }

      fab!(:bookmark_1) { Bookmark.create!(bookmarkable: message_1, user: current_user) }
      fab!(:bookmark_2) { Bookmark.create!(bookmarkable: message_2, user: current_user) }

      before do
        chat_page.prefers_drawer
        category_channel_2.add(current_user)
      end

      it "supports visiting multiple chat bookmarks from the user menu" do
        visit("/")

        user_menu.open
        user_menu.click_bookmarks_tab

        expect(user_menu).to have_bookmark_count_of(2)

        user_menu.click_bookmark(bookmark_1)

        expect(channel_page).to have_bookmarked_message(message_1)

        user_menu.open
        user_menu.click_bookmarks_tab

        user_menu.click_bookmark(bookmark_2)

        expect(channel_page).to have_bookmarked_message(message_2)
      end
    end

    context "when the user has a bookmark auto_delete_preference" do
      before do
        current_user.user_option.update!(
          bookmark_auto_delete_preference: Bookmark.auto_delete_preferences[:on_owner_reply],
        )
      end

      it "is respected when the user creates a new bookmark" do
        chat_page.visit_channel(category_channel_1)
        channel_page.bookmark_message(message_1)

        bookmark_modal.save
        expect(channel_page).to have_bookmarked_message(message_1)

        bookmark = Bookmark.find_by(bookmarkable: message_1, user: current_user)
        expect(bookmark.auto_delete_preference).to eq(
          Bookmark.auto_delete_preferences[:on_owner_reply],
        )
      end
    end

    it "creates a bookmark with a reminder and clears its notification on deletion" do
      chat_page.visit_channel(category_channel_1)
      channel_page.bookmark_message(message_1)
      bookmark_modal.fill_name("Check this out later")
      bookmark_modal.select_preset_reminder(:next_month)

      expect(channel_page).to have_bookmarked_message(message_1)

      bookmark = Bookmark.find_by(bookmarkable: message_1, user: current_user)
      Chat::MessageBookmarkable.send_reminder_notification(
        bookmark,
        data: {
          title: bookmark.bookmarkable.chat_channel.title(current_user),
          bookmarkable_url: bookmark.bookmarkable.url,
        },
      )

      user_menu.open

      expect(page).to have_css("#quick-access-all-notifications .bookmark-reminder")

      channel_page.bookmark_message(message_1)
      bookmark_modal.delete
      bookmark_modal.confirm_delete
      user_menu.open

      expect(find("#quick-access-all-notifications")).to have_no_css(".bookmark-reminder")
    end
  end

  context "when mobile", mobile: true do
    it "allows to bookmark a message" do
      chat_page.visit_channel(category_channel_1)
      channel_page.bookmark_message(message_1)

      bookmark_modal.fill_name("Check this out later")
      bookmark_modal.select_preset_reminder(:next_month)

      expect(channel_page).to have_bookmarked_message(message_1)
    end
  end
end
