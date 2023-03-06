# frozen_string_literal: true

RSpec.describe "Bookmark message", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:channel) { PageObjects::Pages::ChatChannel.new }
  let(:bookmark_modal) { PageObjects::Modals::Bookmark.new }

  fab!(:category_channel_1) { Fabricate(:category_channel) }
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: category_channel_1) }

  before do
    chat_system_bootstrap
    category_channel_1.add(current_user)
    sign_in(current_user)
  end

  context "when desktop" do
    it "allows to bookmark a message" do
      chat.visit_channel(category_channel_1)
      channel.bookmark_message(message_1)

      bookmark_modal.fill_name("Check this out later")
      bookmark_modal.select_preset_reminder(:next_month)

      expect(channel).to have_bookmarked_message(message_1)
    end

    context "when the user has a bookmark auto_delete_preference" do
      before do
        current_user.user_option.update!(
          bookmark_auto_delete_preference: Bookmark.auto_delete_preferences[:on_owner_reply],
        )
      end

      it "is respected when the user creates a new bookmark" do
        chat.visit_channel(category_channel_1)
        channel.bookmark_message(message_1)

        bookmark_modal.save
        expect(channel).to have_bookmarked_message(message_1)

        bookmark = Bookmark.find_by(bookmarkable: message_1, user: current_user)
        expect(bookmark.auto_delete_preference).to eq(
          Bookmark.auto_delete_preferences[:on_owner_reply],
        )
      end
    end
  end

  context "when mobile", mobile: true do
    it "allows to bookmark a message" do
      chat.visit_channel(category_channel_1)

      i = 0.5
      try_until_success(timeout: 20) do
        channel.message_by_id(message_1.id).click(delay: i)
        first(".bookmark-btn")
        i += 0.1
      end
      find(".bookmark-btn").click

      bookmark_modal.fill_name("Check this out later")
      bookmark_modal.select_preset_reminder(:next_month)

      expect(channel).to have_bookmarked_message(message_1)
    end
  end
end
