# frozen_string_literal: true

RSpec.describe BookmarkManager do
  let(:user) { Fabricate(:user) }

  let(:reminder_at) { 1.day.from_now }
  fab!(:post) { Fabricate(:post) }
  let(:name) { 'Check this out!' }

  subject { described_class.new(user) }

  describe ".create" do
    it "creates the bookmark for the user" do
      subject.create(post_id: post.id, name: name)
      bookmark = Bookmark.find_by(user: user)

      expect(bookmark.post_id).to eq(post.id)
      expect(bookmark.topic_id).to eq(post.topic_id)
    end

    it "allows creating a bookmark for the topic and for the first post" do
      subject.create(post_id: post.id, name: name, for_topic: true)
      bookmark = Bookmark.find_by(user: user, post_id: post.id, for_topic: true)

      expect(bookmark.post_id).to eq(post.id)
      expect(bookmark.topic_id).to eq(post.topic_id)
      expect(bookmark.for_topic).to eq(true)

      subject.create(post_id: post.id, name: name)
      bookmark = Bookmark.find_by(user: user, post_id: post.id, for_topic: false)

      expect(bookmark.post_id).to eq(post.id)
      expect(bookmark.topic_id).to eq(post.topic_id)
      expect(bookmark.for_topic).to eq(false)
    end

    # TODO (martin) [POLYBOOK] Not relevant once polymorphic bookmarks are implemented.
    # Topic bookmarks will be distinct, not attached to a post.
    it "errors when creating a for_topic bookmark for a post that is not the first one" do
      subject.create(post_id: Fabricate(:post, topic: post.topic).id, name: name, for_topic: true)
      expect(subject.errors.full_messages).to include(I18n.t("bookmarks.errors.for_topic_must_use_first_post"))
    end

    it "when topic is deleted it raises invalid access" do
      post.topic.trash!
      expect { subject.create(post_id: post.id, name: name) }.to raise_error(Discourse::InvalidAccess)
    end

    it "when post is deleted it raises invalid access" do
      post.trash!
      expect { subject.create(post_id: post.id, name: name) }.to raise_error(Discourse::InvalidAccess)
    end

    it "updates the topic user bookmarked column to true if any post is bookmarked" do
      subject.create(post_id: post.id, name: name, reminder_at: reminder_at)
      tu = TopicUser.find_by(user: user)
      expect(tu.bookmarked).to eq(true)
      tu.update(bookmarked: false)
      subject.create(post_id: Fabricate(:post, topic: post.topic).id)
      tu.reload
      expect(tu.bookmarked).to eq(true)
    end

    context "when a reminder time is provided" do
      it "saves the values correctly" do
        subject.create(post_id: post.id, name: name, reminder_at: reminder_at)
        bookmark = Bookmark.find_by(user: user)

        expect(bookmark.reminder_at).to eq_time(reminder_at)
        expect(bookmark.reminder_set_at).not_to eq(nil)
      end
    end

    context "when options are provided" do
      let(:options) { { auto_delete_preference: Bookmark.auto_delete_preferences[:when_reminder_sent] } }

      it "saves any additional options successfully" do
        subject.create(post_id: post.id, name: name, options: options)
        bookmark = Bookmark.find_by(user: user)

        expect(bookmark.auto_delete_preference).to eq(1)
      end
    end

    context "when the bookmark already exists for the user & post" do
      before do
        Bookmark.create(post: post, user: user)
      end

      it "adds an error to the manager" do
        subject.create(post_id: post.id)
        expect(subject.errors.full_messages).to include(I18n.t("bookmarks.errors.already_bookmarked_post"))
      end
    end

    context "when the bookmark name is too long" do
      it "adds an error to the manager" do
        subject.create(post_id: post.id, name: "test" * 100)
        expect(subject.errors.full_messages).to include("Name is too long (maximum is 100 characters)")
      end
    end

    context "when the reminder time is in the past" do
      let(:reminder_at) { 10.days.ago }

      it "adds an error to the manager" do
        subject.create(post_id: post.id, name: name, reminder_at: reminder_at)
        expect(subject.errors.full_messages).to include(I18n.t("bookmarks.errors.cannot_set_past_reminder"))
      end
    end

    context "when the reminder time is far-flung (> 10 years from now)" do
      let(:reminder_at) { 11.years.from_now }

      it "adds an error to the manager" do
        subject.create(post_id: post.id, name: name, reminder_at: reminder_at)
        expect(subject.errors.full_messages).to include(I18n.t("bookmarks.errors.cannot_set_reminder_in_distant_future"))
      end
    end

    context "when the post is inaccessible for the user" do
      before do
        post.trash!
      end
      it "raises an invalid access error" do
        expect { subject.create(post_id: post.id, name: name) }.to raise_error(Discourse::InvalidAccess)
      end
    end

    context "when the topic is inaccessible for the user" do
      before do
        post.topic.update(category: Fabricate(:private_category, group: Fabricate(:group)))
      end
      it "raises an invalid access error" do
        expect { subject.create(post_id: post.id, name: name) }.to raise_error(Discourse::InvalidAccess)
      end
    end

    it "saves user's preference" do
      subject.create(post_id: post.id, options: { auto_delete_preference: Bookmark.auto_delete_preferences[:when_reminder_sent] })
      expect(user.user_option.bookmark_auto_delete_preference).to eq(Bookmark.auto_delete_preferences[:when_reminder_sent])

      bookmark = Bookmark.find_by(user: user)
      subject.update(bookmark_id: bookmark, name: "test", reminder_at: 1.day.from_now, options: { auto_delete_preference: Bookmark.auto_delete_preferences[:on_owner_reply] })
      expect(user.user_option.bookmark_auto_delete_preference).to eq(Bookmark.auto_delete_preferences[:on_owner_reply])
    end
  end

  describe ".destroy" do
    let!(:bookmark) { Fabricate(:bookmark, user: user, post: post) }
    it "deletes the existing bookmark" do
      subject.destroy(bookmark.id)
      expect(Bookmark.exists?(id: bookmark.id)).to eq(false)
    end

    # TODO (martin) [POLYBOOK] Not relevant once polymorphic bookmarks are implemented.
    context "if the bookmark is the last one bookmarked in the topic" do
      it "marks the topic user bookmarked column as false" do
        TopicUser.create(user: user, topic: bookmark.post.topic, bookmarked: true)
        subject.destroy(bookmark.id)
        tu = TopicUser.find_by(user: user)
        expect(tu.bookmarked).to eq(false)
      end
    end

    context "if the bookmark is the last one bookmarked in the topic (polymorphic)" do
      before do
        SiteSetting.use_polymorphic_bookmarks = true
      end
      it "marks the topic user bookmarked column as false" do
        poly_bookmark = Fabricate(:bookmark, user: user, bookmarkable: post)
        TopicUser.create(user: user, topic: post.topic, bookmarked: true)
        subject.destroy(poly_bookmark.id)
        tu = TopicUser.find_by(user: user)
        expect(tu.bookmarked).to eq(false)
      end
    end

    context "if the bookmark is belonging to some other user" do
      let!(:bookmark) { Fabricate(:bookmark, user: Fabricate(:admin), post: post) }
      it "raises an invalid access error" do
        expect { subject.destroy(bookmark.id) }.to raise_error(Discourse::InvalidAccess)
      end
    end

    context "if the bookmark no longer exists" do
      it "raises a not found error" do
        expect { subject.destroy(9999) }.to raise_error(Discourse::NotFound)
      end
    end
  end

  describe ".update" do
    let!(:bookmark) { Fabricate(:bookmark_next_business_day_reminder, user: user, post: post, name: "Old name") }
    let(:new_name) { "Some new name" }
    let(:new_reminder_at) { 10.days.from_now }
    let(:options) { {} }

    def update_bookmark
      subject.update(
        bookmark_id: bookmark.id,
        name: new_name,
        reminder_at: new_reminder_at,
        options: options
      )
    end

    it "saves the time and new name successfully" do
      update_bookmark
      bookmark.reload
      expect(bookmark.name).to eq(new_name)
      expect(bookmark.reminder_last_sent_at).to eq(nil)
    end

    it "does not reminder_last_sent_at if reminder did not change" do
      bookmark.update(reminder_last_sent_at: 1.day.ago)
      subject.update(bookmark_id: bookmark.id, name: new_name, reminder_at: bookmark.reminder_at)
      bookmark.reload
      expect(bookmark.reminder_last_sent_at).not_to eq(nil)
    end

    context "when options are provided" do
      let(:options) { { auto_delete_preference: Bookmark.auto_delete_preferences[:when_reminder_sent] } }

      it "saves any additional options successfully" do
        update_bookmark
        bookmark.reload
        expect(bookmark.auto_delete_preference).to eq(1)
      end
    end

    context "if the bookmark is belonging to some other user" do
      let!(:bookmark) { Fabricate(:bookmark, user: Fabricate(:admin), post: post) }
      it "raises an invalid access error" do
        expect { update_bookmark }.to raise_error(Discourse::InvalidAccess)
      end
    end

    context "if the bookmark no longer exists" do
      before do
        bookmark.destroy!
      end
      it "raises a not found error" do
        expect { update_bookmark }.to raise_error(Discourse::NotFound)
      end
    end
  end

  describe ".destroy_for_topic" do
    let!(:topic) { Fabricate(:topic) }
    let!(:bookmark1) { Fabricate(:bookmark, post: Fabricate(:post, topic: topic), user: user) }
    let!(:bookmark2) { Fabricate(:bookmark, post: Fabricate(:post, topic: topic), user: user) }

    it "destroys all bookmarks for the topic for the specified user" do
      subject.destroy_for_topic(topic)
      expect(Bookmark.for_user_in_topic(user.id, topic.id).length).to eq(0)
    end

    it "does not destroy any other user's topic bookmarks" do
      user2 = Fabricate(:user)
      Fabricate(:bookmark, post: Fabricate(:post, topic: topic), user: user2)
      subject.destroy_for_topic(topic)
      expect(Bookmark.for_user_in_topic(user2.id, topic.id).length).to eq(1)
    end

    it "updates the topic user bookmarked column to false" do
      TopicUser.create(user: user, topic: topic, bookmarked: true)
      subject.destroy_for_topic(topic)
      tu = TopicUser.find_by(user: user)
      expect(tu.bookmarked).to eq(false)
    end
  end

  describe ".destroy_for_topic (polymorphic)" do
    before do
      SiteSetting.use_polymorphic_bookmarks = true
    end

    let!(:topic) { Fabricate(:topic) }
    let!(:bookmark1) { Fabricate(:bookmark, bookmarkable: Fabricate(:post, topic: topic), user: user) }
    let!(:bookmark2) { Fabricate(:bookmark, bookmarkable: Fabricate(:post, topic: topic), user: user) }

    it "destroys all bookmarks for the topic for the specified user" do
      subject.destroy_for_topic(topic)
      expect(Bookmark.for_user_in_topic(user.id, topic.id).length).to eq(0)
    end

    it "does not destroy any other user's topic bookmarks" do
      user2 = Fabricate(:user)
      Fabricate(:bookmark, bookmarkable: Fabricate(:post, topic: topic), user: user2)
      subject.destroy_for_topic(topic)
      expect(Bookmark.for_user_in_topic(user2.id, topic.id).length).to eq(1)
    end

    it "updates the topic user bookmarked column to false" do
      TopicUser.create(user: user, topic: topic, bookmarked: true)
      subject.destroy_for_topic(topic)
      tu = TopicUser.find_by(user: user)
      expect(tu.bookmarked).to eq(false)
    end
  end

  describe ".send_reminder_notification" do
    let(:bookmark) { Fabricate(:bookmark, user: user) }
    it "sets the reminder_last_sent_at" do
      expect(bookmark.reminder_last_sent_at).to eq(nil)
      described_class.send_reminder_notification(bookmark.id)
      bookmark.reload
      expect(bookmark.reminder_last_sent_at).not_to eq(nil)
    end

    it "creates a notification for the reminder" do
      described_class.send_reminder_notification(bookmark.id)
      notif = notifications_for_user.last
      expect(notif.post_number).to eq(bookmark.post.post_number)
    end

    context "when the bookmark does no longer exist" do
      before do
        bookmark.destroy
      end
      it "does not error, and does not create a notification" do
        described_class.send_reminder_notification(bookmark.id)
        expect(notifications_for_user.any?).to eq(false)
      end
    end

    context "if the post has been deleted" do
      before do
        bookmark.post.trash!
      end
      it "does not error and does not create a notification" do
        described_class.send_reminder_notification(bookmark.id)
        bookmark.reload
        expect(notifications_for_user.any?).to eq(false)
      end
    end

    def notifications_for_user
      Notification.where(notification_type: Notification.types[:bookmark_reminder], user_id: bookmark.user.id)
    end
  end

  describe ".toggle_pin" do
    let!(:bookmark) { Fabricate(:bookmark, user: user) }

    it "sets pinned to false if it is true" do
      bookmark.update(pinned: true)
      subject.toggle_pin(bookmark_id: bookmark.id)
      expect(bookmark.reload.pinned).to eq(false)
    end

    it "sets pinned to true if it is false" do
      bookmark.update(pinned: false)
      subject.toggle_pin(bookmark_id: bookmark.id)
      expect(bookmark.reload.pinned).to eq(true)
    end

    context "if the bookmark is belonging to some other user" do
      let!(:bookmark) { Fabricate(:bookmark, user: Fabricate(:admin)) }
      it "raises an invalid access error" do
        expect { subject.toggle_pin(bookmark_id: bookmark.id) }.to raise_error(Discourse::InvalidAccess)
      end
    end

    context "if the bookmark no longer exists" do
      before do
        bookmark.destroy!
      end
      it "raises a not found error" do
        expect { subject.toggle_pin(bookmark_id: bookmark.id) }.to raise_error(Discourse::NotFound)
      end
    end
  end

  describe "#create_for (use_polymorphic_bookmarks)" do
    before do
      SiteSetting.use_polymorphic_bookmarks = true
    end

    it "allows creating a bookmark for the topic and for the first post" do
      subject.create_for(bookmarkable_id: post.topic_id, bookmarkable_type: "Topic", name: name)
      bookmark = Bookmark.find_by(user: user, bookmarkable: post.topic)
      expect(bookmark.present?).to eq(true)

      subject.create_for(bookmarkable_id: post.id, bookmarkable_type: "Post", name: name)
      bookmark = Bookmark.find_by(user: user, bookmarkable: post)
      expect(bookmark).not_to eq(nil)
    end

    it "when topic is deleted it raises invalid access from guardian check" do
      post.topic.trash!
      expect {
        subject.create_for(bookmarkable_id: post.topic_id, bookmarkable_type: "Topic", name: name)
      }.to raise_error(Discourse::InvalidAccess)
    end

    it "when post is deleted it raises invalid access from guardian check" do
      post.trash!
      expect { subject.create_for(bookmarkable_id: post.id, bookmarkable_type: "Post", name: name) }.to raise_error(Discourse::InvalidAccess)
    end

    it "updates the topic user bookmarked column to true if any post is bookmarked" do
      subject.create_for(bookmarkable_id: post.id, bookmarkable_type: "Post", name: name, reminder_at: reminder_at)
      tu = TopicUser.find_by(user: user)
      expect(tu.bookmarked).to eq(true)
      tu.update(bookmarked: false)
      new_post = Fabricate(:post, topic: post.topic)
      subject.create_for(bookmarkable_id: new_post.id, bookmarkable_type: "Post")
      tu.reload
      expect(tu.bookmarked).to eq(true)
    end

    context "when a reminder time is provided" do
      it "saves the values correctly" do
        subject.create_for(bookmarkable_id: post.id, bookmarkable_type: "Post", name: name, reminder_at: reminder_at)
        bookmark = Bookmark.find_by(user: user, bookmarkable: post)

        expect(bookmark.reminder_at).to eq_time(reminder_at)
        expect(bookmark.reminder_set_at).not_to eq(nil)
      end
    end

    context "when options are provided" do
      let(:options) { { auto_delete_preference: Bookmark.auto_delete_preferences[:when_reminder_sent] } }

      it "saves any additional options successfully" do
        subject.create_for(bookmarkable_id: post.id, bookmarkable_type: "Post", name: name, reminder_at: reminder_at, options: options)
        bookmark = Bookmark.find_by(user: user, bookmarkable: post)

        expect(bookmark.auto_delete_preference).to eq(1)
      end
    end

    context "when the bookmark already exists for the user & post" do
      before do
        Bookmark.create(bookmarkable: post, user: user)
      end

      it "adds an error to the manager" do
        subject.create_for(bookmarkable_id: post.id, bookmarkable_type: "Post")
        expect(subject.errors.full_messages).to include(I18n.t("bookmarks.errors.already_bookmarked", type: "Post"))
      end
    end

    context "when the bookmark name is too long" do
      it "adds an error to the manager" do
        subject.create_for(bookmarkable_id: post.id, bookmarkable_type: "Post", name: "test" * 100)
        expect(subject.errors.full_messages).to include("Name is too long (maximum is 100 characters)")
      end
    end

    context "when the reminder time is in the past" do
      let(:reminder_at) { 10.days.ago }

      it "adds an error to the manager" do
        subject.create_for(bookmarkable_id: post.id, bookmarkable_type: "Post", name: name, reminder_at: reminder_at)
        expect(subject.errors.full_messages).to include(I18n.t("bookmarks.errors.cannot_set_past_reminder"))
      end
    end

    context "when the reminder time is far-flung (> 10 years from now)" do
      let(:reminder_at) { 11.years.from_now }

      it "adds an error to the manager" do
        subject.create_for(bookmarkable_id: post.id, bookmarkable_type: "Post", name: name, reminder_at: reminder_at)
        expect(subject.errors.full_messages).to include(I18n.t("bookmarks.errors.cannot_set_reminder_in_distant_future"))
      end
    end

    context "when the post is inaccessible for the user" do
      before do
        post.trash!
      end
      it "raises an invalid access error" do
        expect { subject.create_for(bookmarkable_id: post.id, bookmarkable_type: "Post", name: name) }.to raise_error(Discourse::InvalidAccess)
      end
    end

    context "when the topic is inaccessible for the user" do
      before do
        post.topic.update(category: Fabricate(:private_category, group: Fabricate(:group)))
      end
      it "raises an invalid access error" do
        expect { subject.create_for(bookmarkable_id: post.id, bookmarkable_type: "Post", name: name) }.to raise_error(Discourse::InvalidAccess)
      end
    end

    it "saves user's preference" do
      subject.create_for(bookmarkable_id: post.id, bookmarkable_type: "Post", options: { auto_delete_preference: Bookmark.auto_delete_preferences[:when_reminder_sent] })
      expect(user.user_option.bookmark_auto_delete_preference).to eq(Bookmark.auto_delete_preferences[:when_reminder_sent])

      bookmark = Bookmark.find_by(user: user)
      subject.update(bookmark_id: bookmark.id, name: "test", reminder_at: 1.day.from_now, options: { auto_delete_preference: Bookmark.auto_delete_preferences[:on_owner_reply] })
      expect(user.user_option.bookmark_auto_delete_preference).to eq(Bookmark.auto_delete_preferences[:on_owner_reply])
    end
  end
end
