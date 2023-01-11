# frozen_string_literal: true

RSpec.describe Jobs::BookmarkReminderNotifications do
  subject { described_class.new }

  fab!(:user) { Fabricate(:user) }
  let(:five_minutes_ago) { Time.zone.now - 5.minutes }
  let(:bookmark1) { Fabricate(:bookmark, user: user) }
  let(:bookmark2) { Fabricate(:bookmark, user: user) }
  let(:bookmark3) { Fabricate(:bookmark, user: user) }
  let!(:bookmarks) { [bookmark1, bookmark2, bookmark3] }

  before do
    # this is done to avoid model validations on Bookmark
    bookmark1.update_column(:reminder_at, five_minutes_ago - 10.minutes)
    bookmark2.update_column(:reminder_at, five_minutes_ago - 5.minutes)
    bookmark3.update_column(:reminder_at, five_minutes_ago)
    Discourse.redis.flushdb
  end

  it "sends every reminder and sets the reminder_last_sent_at" do
    subject.execute
    bookmark1.reload
    bookmark2.reload
    bookmark3.reload
    expect(bookmark1.reminder_last_sent_at).not_to eq(nil)
    expect(bookmark2.reminder_last_sent_at).not_to eq(nil)
    expect(bookmark3.reminder_last_sent_at).not_to eq(nil)
  end

  it "will not send a reminder for a bookmark in the future" do
    freeze_time
    bookmark4 = Fabricate(:bookmark, reminder_at: Time.zone.now + 1.day)
    expect { subject.execute }.to change { Notification.where(user: user).count }.by(3)
    expect(bookmark1.reload.reminder_last_sent_at).to eq_time(Time.zone.now)
    expect(bookmark2.reload.reminder_last_sent_at).to eq_time(Time.zone.now)
    expect(bookmark3.reload.reminder_last_sent_at).to eq_time(Time.zone.now)
    expect(bookmark4.reload.reminder_at).not_to eq(nil)
    expect(bookmark4.reload.reminder_last_sent_at).to eq(nil)
  end

  context "when a user is over the bookmark limit" do
    it "clearing their reminder does not error and hold up the rest" do
      other_bookmark = Fabricate(:bookmark, user: bookmark1.user)
      other_bookmark.update_column(:reminder_at, five_minutes_ago)
      SiteSetting.max_bookmarks_per_user = 2
      expect { subject.execute }.not_to raise_error
    end
  end

  context "when the number of notifications exceed max_reminder_notifications_per_run" do
    it "does not send them in the current run, but will send them in the next" do
      begin
        Jobs::BookmarkReminderNotifications.max_reminder_notifications_per_run = 2
        subject.execute
        expect(bookmark1.reload.reminder_last_sent_at).not_to eq(nil)
        expect(bookmark2.reload.reminder_last_sent_at).not_to eq(nil)
        expect(bookmark3.reload.reminder_last_sent_at).to eq(nil)
      end
    end
  end

  it "will not send notification when topic is not available" do
    bookmark1.bookmarkable.topic.destroy
    bookmark2.bookmarkable.topic.destroy
    bookmark3.bookmarkable.topic.destroy
    expect { subject.execute }.not_to change {
      Notification.where(notification_type: Notification.types[:bookmark_reminder]).count
    }
  end
end
