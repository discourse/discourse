# frozen_string_literal: true

RSpec.describe "Bookmark message", type: :system do
  fab!(:current_user) { Fabricate(:user) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:thread_page) { PageObjects::Pages::ChatThread.new }
  let(:bookmark_modal) { PageObjects::Modals::Bookmark.new }
  let(:user_menu) { PageObjects::Components::UserMenu.new }

  fab!(:category_channel_1) { Fabricate(:category_channel) }
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: category_channel_1) }

  before do
    chat_system_bootstrap
    category_channel_1.add(current_user)
    sign_in(current_user)
  end

  context "when desktop" do
    it "allows to bookmark a message" do
      chat_page.visit_channel(category_channel_1)
      channel_page.bookmark_message(message_1)

      bookmark_modal.fill_name("Check this out later")
      bookmark_modal.select_preset_reminder(:next_month)

      expect(channel_page).to have_bookmarked_message(message_1)
    end

    it "supports linking to a bookmark in a long thread" do
      category_channel_1.update!(threading_enabled: true)
      category_channel_1.add(current_user)

      thread =
        chat_thread_chain_bootstrap(
          channel: category_channel_1,
          users: [current_user, Fabricate(:user)],
          messages_count: Chat::MessagesQuery::MAX_PAGE_SIZE + 1,
        )

      first_message = thread.replies.first

      bookmark = Bookmark.create!(bookmarkable: first_message, user: current_user)

      visit bookmark.bookmarkable.url

      expect(thread_page).to have_bookmarked_message(first_message)
    end

    context "in drawer mode" do
      fab!(:category_channel_2) { Fabricate(:category_channel) }
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
