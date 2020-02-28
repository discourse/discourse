# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Jobs::BookmarkReminder do
  subject { described_class.new }
  let(:args) { { bookmark_id: bookmark.id } }
  let(:bookmark) { Fabricate(:bookmark) }

  it "clears the reminder_at and sets the reminder_last_sent_at" do
    expect(bookmark.reminder_last_sent_at).to eq(nil)
    subject.execute(args)
    bookmark.reload
    expect(bookmark.reminder_at).to eq(nil)
    expect(bookmark.reminder_last_sent_at).not_to eq(nil)
  end

  it "creates a notification for the reminder" do
    subject.execute(args)
    notif = notifications_for_user.last
    expect(notif.post_number).to eq(bookmark.post.post_number)
  end

  context "when the bookmark does no longer exist" do
    before do
      bookmark.destroy
    end
    it "does not error, and does not create a notification" do
      subject.execute(args)
      expect(notifications_for_user.any?).to eq(false)
    end
  end

  context "if the post has been deleted" do
    before do
      bookmark.post.trash!
    end
    it "does not error, and does not create a notification, and clears the reminder" do
      subject.execute(args)
      bookmark.reload
      expect(bookmark.reminder_at).to eq(nil)
      expect(notifications_for_user.any?).to eq(false)
    end
  end

  def notifications_for_user
    Notification.where(notification_type: Notification.types[:bookmark_reminder], user_id: bookmark.user.id)
  end
end
