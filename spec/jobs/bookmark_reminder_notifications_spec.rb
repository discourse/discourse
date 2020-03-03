# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Jobs::BookmarkReminderNotifications do
  subject { described_class.new }

  let(:five_minutes_ago) { Time.now.utc - 5.minutes }
  let(:bookmark1) { Fabricate(:bookmark) }
  let(:bookmark2) { Fabricate(:bookmark) }
  let(:bookmark3) { Fabricate(:bookmark) }
  let!(:bookmarks) do
    [
      bookmark1,
      bookmark2,
      bookmark3
    ]
  end

  before do
    # this is done to avoid model validations on Bookmark
    bookmark1.update_column(:reminder_at, five_minutes_ago - 10.minutes)
    bookmark2.update_column(:reminder_at, five_minutes_ago - 5.minutes)
    bookmark3.update_column(:reminder_at, five_minutes_ago)
  end

  it "sends every reminder and marks the reminder_at to nil for all bookmarks, as well as last sent date" do
    subject.execute
    bookmark1.reload
    bookmark2.reload
    bookmark3.reload
    expect(bookmark1.reminder_at).to eq(nil)
    expect(bookmark1.reminder_last_sent_at).not_to eq(nil)
    expect(bookmark2.reminder_at).to eq(nil)
    expect(bookmark2.reminder_last_sent_at).not_to eq(nil)
    expect(bookmark3.reminder_at).to eq(nil)
    expect(bookmark3.reminder_last_sent_at).not_to eq(nil)
  end

  it "will not send a reminder for a bookmark in the future" do
    bookmark4 = Fabricate(:bookmark, reminder_at: Time.now.utc + 1.day)
    BookmarkReminderNotificationHandler.expects(:send_notification).with(bookmark1)
    BookmarkReminderNotificationHandler.expects(:send_notification).with(bookmark2)
    BookmarkReminderNotificationHandler.expects(:send_notification).with(bookmark3)
    BookmarkReminderNotificationHandler.expects(:send_notification).with(bookmark4).never
    subject.execute
    expect(bookmark4.reload.reminder_at).not_to eq(nil)
  end

  context "when one of the bookmark reminder types is at_desktop" do
    let(:bookmark1) { Fabricate(:bookmark, reminder_type: :at_desktop) }
    it "is not included in the run, because it is not time-based" do
      BookmarkManager.any_instance.expects(:send_reminder_notification).with(bookmark1.id).never
      subject.execute
    end
  end

  context "when the number of notifications exceed MAX_REMINDER_NOTIFICATIONS_PER_RUN" do
    it "does not send them in the current run, but will send them in the next" do
      begin
        original_const = Jobs::BookmarkReminderNotifications::MAX_REMINDER_NOTIFICATIONS_PER_RUN
        Jobs::BookmarkReminderNotifications.send(:remove_const, "MAX_REMINDER_NOTIFICATIONS_PER_RUN")
        Jobs::BookmarkReminderNotifications.const_set("MAX_REMINDER_NOTIFICATIONS_PER_RUN", 2)
        subject.execute
        expect(bookmark1.reload.reminder_at).to eq(nil)
        expect(bookmark2.reload.reminder_at).to eq(nil)
        expect(bookmark3.reload.reminder_at).not_to eq(nil)
      ensure
        Jobs::BookmarkReminderNotifications.send(:remove_const, "MAX_REMINDER_NOTIFICATIONS_PER_RUN")
        Jobs::BookmarkReminderNotifications.const_set("MAX_REMINDER_NOTIFICATIONS_PER_RUN", original_const)
      end
    end
  end
end
