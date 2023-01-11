# frozen_string_literal: true

RSpec.describe BookmarkManager do
  let(:user) { Fabricate(:user) }

  let(:reminder_at) { 1.day.from_now }
  fab!(:post) { Fabricate(:post) }
  let(:name) { "Check this out!" }

  subject { described_class.new(user) }

  describe ".destroy" do
    let!(:bookmark) { Fabricate(:bookmark, user: user, bookmarkable: post) }
    it "deletes the existing bookmark" do
      subject.destroy(bookmark.id)
      expect(Bookmark.exists?(id: bookmark.id)).to eq(false)
    end

    context "if the bookmark is the last one bookmarked in the topic" do
      it "marks the topic user bookmarked column as false" do
        TopicUser.create(user: user, topic: post.topic, bookmarked: true)
        subject.destroy(bookmark.id)
        tu = TopicUser.find_by(user: user)
        expect(tu.bookmarked).to eq(false)
      end
    end

    context "if the bookmark is belonging to some other user" do
      let!(:bookmark) { Fabricate(:bookmark, user: Fabricate(:admin), bookmarkable: post) }
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
    let!(:bookmark) do
      Fabricate(
        :bookmark_next_business_day_reminder,
        user: user,
        bookmarkable: post,
        name: "Old name",
      )
    end
    let(:new_name) { "Some new name" }
    let(:new_reminder_at) { 10.days.from_now }
    let(:options) { {} }

    def update_bookmark
      subject.update(
        bookmark_id: bookmark.id,
        name: new_name,
        reminder_at: new_reminder_at,
        options: options,
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
      let(:options) do
        { auto_delete_preference: Bookmark.auto_delete_preferences[:when_reminder_sent] }
      end

      it "saves any additional options successfully" do
        update_bookmark
        bookmark.reload
        expect(bookmark.auto_delete_preference).to eq(1)
      end
    end

    context "if the bookmark is belonging to some other user" do
      let!(:bookmark) { Fabricate(:bookmark, user: Fabricate(:admin), bookmarkable: post) }
      it "raises an invalid access error" do
        expect { update_bookmark }.to raise_error(Discourse::InvalidAccess)
      end
    end

    context "if the bookmark no longer exists" do
      before { bookmark.destroy! }
      it "raises a not found error" do
        expect { update_bookmark }.to raise_error(Discourse::NotFound)
      end
    end
  end

  describe ".destroy_for_topic" do
    let!(:topic) { Fabricate(:topic) }
    let!(:bookmark1) do
      Fabricate(:bookmark, bookmarkable: Fabricate(:post, topic: topic), user: user)
    end
    let!(:bookmark2) do
      Fabricate(:bookmark, bookmarkable: Fabricate(:post, topic: topic), user: user)
    end

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
      expect(notif.post_number).to eq(bookmark.bookmarkable.post_number)
    end

    context "when the bookmark does no longer exist" do
      before { bookmark.destroy }
      it "does not error, and does not create a notification" do
        described_class.send_reminder_notification(bookmark.id)
        expect(notifications_for_user.any?).to eq(false)
      end
    end

    context "if the post has been deleted" do
      before { bookmark.bookmarkable.trash! }
      it "does not error and does not create a notification" do
        described_class.send_reminder_notification(bookmark.id)
        bookmark.reload
        expect(notifications_for_user.any?).to eq(false)
      end
    end

    def notifications_for_user
      Notification.where(
        notification_type: Notification.types[:bookmark_reminder],
        user_id: bookmark.user.id,
      )
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
        expect { subject.toggle_pin(bookmark_id: bookmark.id) }.to raise_error(
          Discourse::InvalidAccess,
        )
      end
    end

    context "if the bookmark no longer exists" do
      before { bookmark.destroy! }
      it "raises a not found error" do
        expect { subject.toggle_pin(bookmark_id: bookmark.id) }.to raise_error(Discourse::NotFound)
      end
    end
  end

  describe "#create_for" do
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
      expect do
        subject.create_for(bookmarkable_id: post.id, bookmarkable_type: "Post", name: name)
      end.to raise_error(Discourse::InvalidAccess)
    end

    it "adds a validation error when the bookmarkable_type is not registered" do
      subject.create_for(bookmarkable_id: post.id, bookmarkable_type: "BlahFactory", name: name)
      expect(subject.errors.full_messages).to include(
        I18n.t("bookmarks.errors.invalid_bookmarkable", type: "BlahFactory"),
      )
    end

    it "updates the topic user bookmarked column to true if any post is bookmarked" do
      subject.create_for(
        bookmarkable_id: post.id,
        bookmarkable_type: "Post",
        name: name,
        reminder_at: reminder_at,
      )
      tu = TopicUser.find_by(user: user)
      expect(tu.bookmarked).to eq(true)
      tu.update(bookmarked: false)
      new_post = Fabricate(:post, topic: post.topic)
      subject.create_for(bookmarkable_id: new_post.id, bookmarkable_type: "Post")
      tu.reload
      expect(tu.bookmarked).to eq(true)
    end

    it "sets auto_delete_preference to clear_reminder by default" do
      bookmark =
        subject.create_for(
          bookmarkable_id: post.id,
          bookmarkable_type: "Post",
          name: name,
          reminder_at: reminder_at,
        )
      expect(bookmark.auto_delete_preference).to eq(
        Bookmark.auto_delete_preferences[:clear_reminder],
      )
    end

    context "when the user has set their bookmark_auto_delete_preference" do
      before do
        user.user_option.update!(
          bookmark_auto_delete_preference: Bookmark.auto_delete_preferences[:on_owner_reply],
        )
      end

      it "sets auto_delete_preferences to the user's user_option.bookmark_auto_delete_preference" do
        bookmark =
          subject.create_for(
            bookmarkable_id: post.id,
            bookmarkable_type: "Post",
            name: name,
            reminder_at: reminder_at,
          )
        expect(bookmark.auto_delete_preference).to eq(
          Bookmark.auto_delete_preferences[:on_owner_reply],
        )
      end

      it "uses the passed in auto_delete_preference option instead of the user's one" do
        bookmark =
          subject.create_for(
            bookmarkable_id: post.id,
            bookmarkable_type: "Post",
            name: name,
            reminder_at: reminder_at,
            options: {
              auto_delete_preference: Bookmark.auto_delete_preferences[:when_reminder_sent],
            },
          )
        expect(bookmark.auto_delete_preference).to eq(
          Bookmark.auto_delete_preferences[:when_reminder_sent],
        )
      end
    end

    context "when a reminder time is provided" do
      it "saves the values correctly" do
        subject.create_for(
          bookmarkable_id: post.id,
          bookmarkable_type: "Post",
          name: name,
          reminder_at: reminder_at,
        )
        bookmark = Bookmark.find_by(user: user, bookmarkable: post)

        expect(bookmark.reminder_at).to eq_time(reminder_at)
        expect(bookmark.reminder_set_at).not_to eq(nil)
      end
    end

    context "when options are provided" do
      let(:options) do
        { auto_delete_preference: Bookmark.auto_delete_preferences[:when_reminder_sent] }
      end

      it "saves any additional options successfully" do
        subject.create_for(
          bookmarkable_id: post.id,
          bookmarkable_type: "Post",
          name: name,
          reminder_at: reminder_at,
          options: options,
        )
        bookmark = Bookmark.find_by(user: user, bookmarkable: post)

        expect(bookmark.auto_delete_preference).to eq(1)
      end
    end

    context "when the bookmark already exists for the user & post" do
      before { Bookmark.create(bookmarkable: post, user: user) }

      it "adds an error to the manager" do
        subject.create_for(bookmarkable_id: post.id, bookmarkable_type: "Post")
        expect(subject.errors.full_messages).to include(
          I18n.t("bookmarks.errors.already_bookmarked", type: "Post"),
        )
      end
    end

    context "when the bookmark name is too long" do
      it "adds an error to the manager" do
        subject.create_for(bookmarkable_id: post.id, bookmarkable_type: "Post", name: "test" * 100)
        expect(subject.errors.full_messages).to include(
          "Name is too long (maximum is 100 characters)",
        )
      end
    end

    context "when the reminder time is in the past" do
      let(:reminder_at) { 10.days.ago }

      it "adds an error to the manager" do
        subject.create_for(
          bookmarkable_id: post.id,
          bookmarkable_type: "Post",
          name: name,
          reminder_at: reminder_at,
        )
        expect(subject.errors.full_messages).to include(
          I18n.t("bookmarks.errors.cannot_set_past_reminder"),
        )
      end
    end

    context "when the reminder time is far-flung (> 10 years from now)" do
      let(:reminder_at) { 11.years.from_now }

      it "adds an error to the manager" do
        subject.create_for(
          bookmarkable_id: post.id,
          bookmarkable_type: "Post",
          name: name,
          reminder_at: reminder_at,
        )
        expect(subject.errors.full_messages).to include(
          I18n.t("bookmarks.errors.cannot_set_reminder_in_distant_future"),
        )
      end
    end

    context "when the post is inaccessible for the user" do
      before { post.trash! }
      it "raises an invalid access error" do
        expect {
          subject.create_for(bookmarkable_id: post.id, bookmarkable_type: "Post", name: name)
        }.to raise_error(Discourse::InvalidAccess)
      end
    end

    context "when the topic is inaccessible for the user" do
      before { post.topic.update(category: Fabricate(:private_category, group: Fabricate(:group))) }
      it "raises an invalid access error" do
        expect {
          subject.create_for(bookmarkable_id: post.id, bookmarkable_type: "Post", name: name)
        }.to raise_error(Discourse::InvalidAccess)
      end
    end
  end
end
