# frozen_string_literal: true

require "rails_helper"

RSpec.describe TopicBookmarkable do
  subject(:registered_bookmarkable) { RegisteredBookmarkable.new(TopicBookmarkable) }

  fab!(:user) { Fabricate(:user) }
  fab!(:private_category) { Fabricate(:private_category, group: Fabricate(:group)) }

  let(:guardian) { Guardian.new(user) }

  let!(:topic1) { Fabricate(:topic) }
  let!(:topic2) { Fabricate(:topic) }
  let!(:post) { Fabricate(:post, topic: topic1) }
  let!(:bookmark1) do
    Fabricate(:bookmark, user: user, bookmarkable: topic1, name: "something i gotta do")
  end
  let!(:bookmark2) { Fabricate(:bookmark, user: user, bookmarkable: topic2) }
  let!(:bookmark3) { Fabricate(:bookmark) }
  let!(:topic_user1) { Fabricate(:topic_user, user: user, topic: topic1) }
  let!(:topic_user2) { Fabricate(:topic_user, user: user, topic: topic2) }

  describe "#perform_list_query" do
    it "returns all the user's bookmarks" do
      expect(registered_bookmarkable.perform_list_query(user, guardian).map(&:id)).to match_array(
        [bookmark1.id, bookmark2.id],
      )
    end

    it "does not return bookmarks for posts where the user does not have access to the topic category" do
      bookmark1.bookmarkable.update!(category: private_category)
      expect(registered_bookmarkable.perform_list_query(user, guardian).map(&:id)).to match_array(
        [bookmark2.id],
      )
    end

    it "does not return bookmarks for posts where the user does not have access to the private message" do
      bookmark1.update!(bookmarkable: Fabricate(:private_message_topic))
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

    it "returns bookmarks that match by post search data (topic title or post content)" do
      post.update(raw: "some post content")
      topic1.update(title: "a great topic title")

      ts_query = Search.ts_query(term: "post content", ts_config: "simple")
      expect(
        registered_bookmarkable.perform_search_query(
          registered_bookmarkable.perform_list_query(user, guardian),
          "%post content%",
          ts_query,
        ).map(&:id),
      ).to match_array([bookmark1.id])

      ts_query = Search.ts_query(term: "great topic", ts_config: "simple")
      expect(
        registered_bookmarkable.perform_search_query(
          registered_bookmarkable.perform_list_query(user, guardian),
          "%great topic%",
          ts_query,
        ).map(&:id),
      ).to match_array([bookmark1.id])

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
    it "cannot send reminder if the topic is deleted" do
      expect(registered_bookmarkable.can_send_reminder?(bookmark1)).to eq(true)
      bookmark1.bookmarkable.trash!
      bookmark1.reload
      expect(registered_bookmarkable.can_send_reminder?(bookmark1)).to eq(false)
    end
  end

  describe "#reminder_handler" do
    it "creates a notification for the user with the correct details" do
      expect { registered_bookmarkable.send_reminder_notification(bookmark1) }.to change {
        Notification.count
      }.by(1)
      notif = user.notifications.last
      expect(notif.notification_type).to eq(Notification.types[:bookmark_reminder])
      expect(notif.topic_id).to eq(bookmark1.bookmarkable_id)
      expect(notif.post_number).to eq(1)
      expect(notif.data).to eq(
        {
          title: bookmark1.bookmarkable.title,
          bookmarkable_url: bookmark1.bookmarkable.first_post.url,
          display_username: bookmark1.user.username,
          bookmark_name: bookmark1.name,
          bookmark_id: bookmark1.id,
        }.to_json,
      )
    end
  end

  describe "#can_see?" do
    it "returns false if the post is in a private category or private message the user cannot see" do
      expect(registered_bookmarkable.can_see?(guardian, bookmark1)).to eq(true)
      bookmark1.bookmarkable.update!(category: private_category)
      expect(registered_bookmarkable.can_see?(guardian, bookmark1)).to eq(false)
      bookmark1.update!(bookmarkable: Fabricate(:private_message_topic))
      expect(registered_bookmarkable.can_see?(guardian, bookmark1)).to eq(false)
    end
  end
end
