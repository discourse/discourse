# frozen_string_literal: true

describe Chat::MessageBookmarkable do
  subject(:registered_bookmarkable) { RegisteredBookmarkable.new(described_class) }

  fab!(:chatters) { Fabricate(:group) }
  fab!(:user) { Fabricate(:user, group_ids: [chatters.id]) }
  fab!(:guardian) { Guardian.new(user) }
  fab!(:other_category) { Fabricate(:private_category, group: Fabricate(:group)) }
  fab!(:category_channel) { Fabricate(:category_channel, chatable: other_category) }
  fab!(:private_category) { Fabricate(:private_category, group: Fabricate(:group)) }
  fab!(:channel) { Fabricate(:category_channel) }

  before do
    register_test_bookmarkable(described_class)
    Chat::UserChatChannelMembership.create(chat_channel: channel, user: user, following: true)
    SiteSetting.chat_allowed_groups = chatters
  end

  after { DiscoursePluginRegistry.reset_register!(:bookmarkables) }

  let!(:message1) { Fabricate(:chat_message, chat_channel: channel) }
  let!(:message2) { Fabricate(:chat_message, chat_channel: channel) }
  let!(:bookmark1) do
    Fabricate(:bookmark, user: user, bookmarkable: message1, name: "something i gotta do")
  end
  let!(:bookmark2) { Fabricate(:bookmark, user: user, bookmarkable: message2) }
  let!(:bookmark3) { Fabricate(:bookmark) }

  describe "#perform_list_query" do
    it "returns all the user's bookmarks" do
      expect(registered_bookmarkable.perform_list_query(user, guardian).map(&:id)).to match_array(
        [bookmark1.id, bookmark2.id],
      )
    end

    it "does not return bookmarks for messages inside category chat channels the user cannot access" do
      channel.update(chatable: other_category)
      expect(registered_bookmarkable.perform_list_query(user, guardian)).to eq(nil)
      other_category.groups.last.add(user)
      bookmark1.reload
      user.reload
      guardian = Guardian.new(user)
      expect(registered_bookmarkable.perform_list_query(user, guardian).map(&:id)).to match_array(
        [bookmark1.id, bookmark2.id],
      )
    end

    it "does not return bookmarks for messages inside direct message chat channels the user cannot access" do
      direct_message = Fabricate(:direct_message)
      channel.update(chatable: direct_message)
      expect(registered_bookmarkable.perform_list_query(user, guardian)).to eq(nil)
      Chat::DirectMessageUser.create(user: user, direct_message: direct_message)
      bookmark1.reload
      user.reload
      guardian = Guardian.new(user)
      expect(registered_bookmarkable.perform_list_query(user, guardian).map(&:id)).to match_array(
        [bookmark1.id, bookmark2.id],
      )
    end

    it "does not return bookmarks for deleted messages" do
      message1.trash!
      guardian = Guardian.new(user)
      expect(registered_bookmarkable.perform_list_query(user, guardian).map(&:id)).to match_array(
        [bookmark2.id],
      )
    end
  end

  describe "#perform_search_query" do
    before { SearchIndexer.enable }

    it "returns bookmarks that match by name" do
      ts_query = Search.ts_query(term: "gotta", ts_config: "simple")
      expect(
        registered_bookmarkable.perform_search_query(
          registered_bookmarkable.perform_list_query(user, guardian),
          "%gotta%",
          ts_query,
        ).map(&:id),
      ).to match_array([bookmark1.id])
    end

    it "returns bookmarks that match by chat message message content" do
      message2.update(message: "some good soup")

      ts_query = Search.ts_query(term: "good soup", ts_config: "simple")
      expect(
        registered_bookmarkable.perform_search_query(
          registered_bookmarkable.perform_list_query(user, guardian),
          "%good soup%",
          ts_query,
        ).map(&:id),
      ).to match_array([bookmark2.id])

      ts_query = Search.ts_query(term: "blah", ts_config: "simple")
      expect(
        registered_bookmarkable.perform_search_query(
          registered_bookmarkable.perform_list_query(user, guardian),
          "%blah%",
          ts_query,
        ).map(&:id),
      ).to eq([])
    end
  end

  describe "#can_send_reminder?" do
    it "cannot send the reminder if the message or channel is deleted" do
      expect(registered_bookmarkable.can_send_reminder?(bookmark1)).to eq(true)
      bookmark1.bookmarkable.trash!
      bookmark1.reload
      expect(registered_bookmarkable.can_send_reminder?(bookmark1)).to eq(false)
      Chat::Message.with_deleted.find_by(id: bookmark1.bookmarkable_id).recover!
      bookmark1.reload
      bookmark1.bookmarkable.chat_channel.trash!
      bookmark1.reload
      expect(registered_bookmarkable.can_send_reminder?(bookmark1)).to eq(false)
    end

    it "cannot send reminder if the user cannot access the channel" do
      expect(registered_bookmarkable.can_send_reminder?(bookmark1)).to eq(true)
      bookmark1.bookmarkable.update!(chat_channel: Fabricate(:private_category_channel))
      bookmark1.reload
      expect(registered_bookmarkable.can_send_reminder?(bookmark1)).to eq(false)
    end
  end

  describe "#reminder_handler" do
    it "creates a notification for the user with the correct details" do
      expect { registered_bookmarkable.send_reminder_notification(bookmark1) }.to change {
        Notification.count
      }.by(1)
      notification = user.notifications.last
      expect(notification.notification_type).to eq(Notification.types[:bookmark_reminder])
      expect(notification.data).to eq(
        {
          title:
            I18n.t(
              "chat.bookmarkable.notification_title",
              channel_name: bookmark1.bookmarkable.chat_channel.title(bookmark1.user),
            ),
          bookmarkable_url: bookmark1.bookmarkable.url,
          display_username: bookmark1.user.username,
          bookmark_name: bookmark1.name,
          bookmark_id: bookmark1.id,
          bookmarkable_type: bookmark1.bookmarkable_type,
          bookmarkable_id: bookmark1.bookmarkable_id,
        }.to_json,
      )
    end
  end

  describe "#can_see?" do
    it "returns false if the chat message is in a channel the user cannot see" do
      expect(registered_bookmarkable.can_see?(guardian, bookmark1)).to eq(true)
      bookmark1.bookmarkable.chat_channel.update!(chatable: private_category)
      expect(registered_bookmarkable.can_see?(guardian, bookmark1)).to eq(false)
      private_category.groups.last.add(user)
      bookmark1.reload
      user.reload
      guardian = Guardian.new(user)
      expect(registered_bookmarkable.can_see?(guardian, bookmark1)).to eq(true)
    end
  end

  describe "#validate_before_create" do
    it "raises InvalidAccess if the user cannot see the chat channel" do
      expect {
        registered_bookmarkable.validate_before_create(guardian, bookmark1.bookmarkable)
      }.not_to raise_error
      bookmark1.bookmarkable.chat_channel.update!(chatable: private_category)
      expect {
        registered_bookmarkable.validate_before_create(guardian, bookmark1.bookmarkable)
      }.to raise_error(Discourse::InvalidAccess)
      private_category.groups.last.add(user)
      bookmark1.reload
      user.reload
      guardian = Guardian.new(user)
      expect {
        registered_bookmarkable.validate_before_create(guardian, bookmark1.bookmarkable)
      }.not_to raise_error
    end

    it "raises InvalidAccess if the chat message is deleted" do
      expect {
        registered_bookmarkable.validate_before_create(guardian, bookmark1.bookmarkable)
      }.not_to raise_error
      bookmark1.bookmarkable.trash!
      bookmark1.reload
      expect {
        registered_bookmarkable.validate_before_create(guardian, bookmark1.bookmarkable)
      }.to raise_error(Discourse::InvalidAccess)
    end
  end

  describe "#cleanup_deleted" do
    it "deletes bookmarks for chat messages deleted more than 3 days ago" do
      bookmark_post = Fabricate(:bookmark, bookmarkable: Fabricate(:post))
      bookmark1.bookmarkable.trash!
      bookmark1.bookmarkable.update!(deleted_at: 4.days.ago)
      registered_bookmarkable.cleanup_deleted
      expect(Bookmark.exists?(id: bookmark1.id)).to eq(false)
      expect(Bookmark.exists?(id: bookmark2.id)).to eq(true)
      expect(Bookmark.exists?(id: bookmark_post.id)).to eq(true)
    end
  end
end
