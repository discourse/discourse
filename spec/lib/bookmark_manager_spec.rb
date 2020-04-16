# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BookmarkManager do
  let(:user) { Fabricate(:user) }

  let(:reminder_type) { 'tomorrow' }
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

    context "when a reminder time + type is provided" do
      it "saves the values correctly" do
        subject.create(post_id: post.id, name: name, reminder_type: reminder_type, reminder_at: reminder_at)
        bookmark = Bookmark.find_by(user: user)

        expect(bookmark.reminder_at).to eq_time(reminder_at)
        expect(bookmark.reminder_set_at).not_to eq(nil)
        expect(bookmark.reminder_type).to eq(Bookmark.reminder_types[:tomorrow])
      end
    end

    context "when bookmarking the topic level (post is OP)" do
      it "updates the topic user bookmarked column to true" do
        subject.create(post_id: post.id, name: name, reminder_type: reminder_type, reminder_at: reminder_at)
        tu = TopicUser.find_by(user: user)
        expect(tu.bookmarked).to eq(true)
      end
    end

    context "when the reminder type is at_desktop" do
      let(:reminder_type) { 'at_desktop' }
      let(:reminder_at) { nil }

      def create_bookmark
        subject.create(post_id: post.id, name: name, reminder_type: reminder_type, reminder_at: reminder_at)
      end

      it "this is a special case which needs client-side logic and has no reminder_at datetime" do
        create_bookmark
        bookmark = Bookmark.find_by(user: user)

        expect(bookmark.reminder_at).to eq(nil)
        expect(bookmark.reminder_type).to eq(Bookmark.reminder_types[:at_desktop])
      end

      it "sets a redis key for the user so we know they have a pending at_desktop reminder" do
        create_bookmark
        expect(Discourse.redis.get("pending_at_desktop_bookmark_reminder_user_#{user.id}")).not_to eq(nil)
      end
    end

    context "when the bookmark already exists for the user & post" do
      before do
        Bookmark.create(post: post, user: user, topic: post.topic)
      end

      it "adds an error to the manager" do
        subject.create(post_id: post.id)
        expect(subject.errors.full_messages).to include(I18n.t("bookmarks.errors.already_bookmarked_post"))
      end
    end

    context "when the reminder time is not provided when it needs to be" do
      let(:reminder_at) { nil }
      it "adds an error to the manager" do
        subject.create(post_id: post.id, name: name, reminder_type: reminder_type, reminder_at: reminder_at)
        expect(subject.errors.full_messages).to include(
          "Reminder at " + I18n.t("bookmarks.errors.time_must_be_provided", reminder_type: I18n.t("bookmarks.reminders.at_desktop"))
        )
      end
    end

    context "when the reminder time is in the past" do
      let(:reminder_at) { 10.days.ago }

      it "adds an error to the manager" do
        subject.create(post_id: post.id, name: name, reminder_type: reminder_type, reminder_at: reminder_at)
        expect(subject.errors.full_messages).to include(I18n.t("bookmarks.errors.cannot_set_past_reminder"))
      end
    end

    context "when the reminder time is far-flung (> 10 years from now)" do
      let(:reminder_at) { 11.years.from_now }

      it "adds an error to the manager" do
        subject.create(post_id: post.id, name: name, reminder_type: reminder_type, reminder_at: reminder_at)
        expect(subject.errors.full_messages).to include(I18n.t("bookmarks.errors.cannot_set_reminder_in_distant_future"))
      end
    end

    context "when the post is inaccessable for the user" do
      before do
        post.trash!
      end
      it "raises an invalid access error" do
        expect { subject.create(post_id: post.id, name: name) }.to raise_error(Discourse::InvalidAccess)
      end
    end

    context "when the topic is inaccessable for the user" do
      before do
        post.topic.update(category: Fabricate(:private_category, group: Fabricate(:group)))
      end
      it "raises an invalid access error" do
        expect { subject.create(post_id: post.id, name: name) }.to raise_error(Discourse::InvalidAccess)
      end
    end
  end

  describe ".destroy" do
    let!(:bookmark) { Fabricate(:bookmark, user: user, post: post) }
    it "deletes the existing bookmark" do
      subject.destroy(bookmark.id)
      expect(Bookmark.exists?(id: bookmark.id)).to eq(false)
    end

    context "if the bookmark is belonging to some other user" do
      let!(:bookmark) { Fabricate(:bookmark, user: Fabricate(:admin), post: post) }
      it "raises an invalid access error" do
        expect { subject.destroy(bookmark.id) }.to raise_error(Discourse::InvalidAccess)
      end
    end

    context "if the bookmark no longer exists" do
      it "raises an invalid access error" do
        expect { subject.destroy(9999) }.to raise_error(Discourse::NotFound)
      end
    end

    context "if the user has pending at desktop reminders for another bookmark" do
      before do
        Fabricate(:bookmark, user: user, post: Fabricate(:post), reminder_type: Bookmark.reminder_types[:at_desktop])
        BookmarkReminderNotificationHandler.cache_pending_at_desktop_reminder(user)
      end
      it "does not clear the at bookmark redis key" do
        subject.destroy(bookmark.id)
        expect(BookmarkReminderNotificationHandler.user_has_pending_at_desktop_reminders?(user)).to eq(true)
      end
    end

    context "if the user has pending at desktop reminders for another bookmark" do
      it "does clear the at bookmark redis key" do
        BookmarkReminderNotificationHandler.cache_pending_at_desktop_reminder(user)
        subject.destroy(bookmark.id)
        expect(BookmarkReminderNotificationHandler.user_has_pending_at_desktop_reminders?(user)).to eq(false)
      end
    end
  end

  describe ".destroy_for_topic" do
    let!(:topic) { Fabricate(:topic) }
    let!(:bookmark1) { Fabricate(:bookmark, topic: topic, post: Fabricate(:post, topic: topic), user: user) }
    let!(:bookmark2) { Fabricate(:bookmark, topic: topic, post: Fabricate(:post, topic: topic), user: user) }

    it "destroys all bookmarks for the topic for the specified user" do
      subject.destroy_for_topic(topic)
      expect(Bookmark.where(user: user, topic: topic).length).to eq(0)
    end

    it "does not destroy any other user's topic bookmarks" do
      user2 = Fabricate(:user)
      Fabricate(:bookmark, topic: topic, post: Fabricate(:post, topic: topic), user: user2)
      subject.destroy_for_topic(topic)
      expect(Bookmark.where(user: user2, topic: topic).length).to eq(1)
    end

    context "if the user has pending at desktop reminders for another bookmark" do
      before do
        Fabricate(:bookmark, user: user, post: Fabricate(:post), reminder_type: Bookmark.reminder_types[:at_desktop])
        BookmarkReminderNotificationHandler.cache_pending_at_desktop_reminder(user)
      end
      it "does not clear the at bookmark redis key" do
        subject.destroy_for_topic(topic)
        expect(BookmarkReminderNotificationHandler.user_has_pending_at_desktop_reminders?(user)).to eq(true)
      end
    end

    context "if the user has pending at desktop reminders for another bookmark" do
      it "does clear the at bookmark redis key" do
        BookmarkReminderNotificationHandler.cache_pending_at_desktop_reminder(user)
        subject.destroy_for_topic(topic)
        expect(BookmarkReminderNotificationHandler.user_has_pending_at_desktop_reminders?(user)).to eq(false)
      end
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
    it "clears the reminder_at and sets the reminder_last_sent_at" do
      expect(bookmark.reminder_last_sent_at).to eq(nil)
      described_class.send_reminder_notification(bookmark.id)
      bookmark.reload
      expect(bookmark.reminder_at).to eq(nil)
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
      it "does not error, and does not create a notification, and clears the reminder" do
        described_class.send_reminder_notification(bookmark.id)
        bookmark.reload
        expect(bookmark.reminder_at).to eq(nil)
        expect(notifications_for_user.any?).to eq(false)
      end
    end

    def notifications_for_user
      Notification.where(notification_type: Notification.types[:bookmark_reminder], user_id: bookmark.user.id)
    end
  end
end
