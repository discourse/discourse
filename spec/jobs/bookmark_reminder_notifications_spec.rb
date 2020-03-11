# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Jobs::BookmarkReminderNotifications do
  subject { described_class.new }

  let(:five_minutes_ago) { Time.zone.now - 5.minutes }
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
    SiteSetting.enable_bookmarks_with_reminders = true
    # this is done to avoid model validations on Bookmark
    bookmark1.update_column(:reminder_at, five_minutes_ago - 10.minutes)
    bookmark2.update_column(:reminder_at, five_minutes_ago - 5.minutes)
    bookmark3.update_column(:reminder_at, five_minutes_ago)
    Discourse.redis.flushall
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
    bookmark4 = Fabricate(:bookmark, reminder_at: Time.zone.now + 1.day)
    BookmarkReminderNotificationHandler.expects(:send_notification).with(bookmark1)
    BookmarkReminderNotificationHandler.expects(:send_notification).with(bookmark2)
    BookmarkReminderNotificationHandler.expects(:send_notification).with(bookmark3)
    BookmarkReminderNotificationHandler.expects(:send_notification).with(bookmark4).never
    subject.execute
    expect(bookmark4.reload.reminder_at).not_to eq(nil)
  end

  it "increments the job run number correctly and resets to 1 when it reaches 6" do
    expect(Discourse.redis.get(described_class::JOB_RUN_NUMBER_KEY)).to eq(nil)
    subject.execute
    expect(Discourse.redis.get(described_class::JOB_RUN_NUMBER_KEY)).to eq('1')
    subject.execute
    subject.execute
    subject.execute
    subject.execute
    subject.execute
    expect(Discourse.redis.get(described_class::JOB_RUN_NUMBER_KEY)).to eq('6')
    subject.execute
    expect(Discourse.redis.get(described_class::JOB_RUN_NUMBER_KEY)).to eq('1')
  end

  context "when the bookmark with reminder site setting is disabled" do
    it "does nothing" do
      Bookmark.expects(:where).never
      SiteSetting.enable_bookmarks_with_reminders = false
      subject.execute
    end
  end

  context "when one of the bookmark reminder types is at_desktop" do
    let(:bookmark1) { Fabricate(:bookmark, reminder_type: :at_desktop) }
    it "is not included in the run, because it is not time-based" do
      BookmarkManager.any_instance.expects(:send_reminder_notification).with(bookmark1.id).never
      subject.execute
    end
  end

  context "when the number of notifications exceed max_reminder_notifications_per_run" do
    it "does not send them in the current run, but will send them in the next" do
      begin
        Jobs::BookmarkReminderNotifications.max_reminder_notifications_per_run = 2
        subject.execute
        expect(bookmark1.reload.reminder_at).to eq(nil)
        expect(bookmark2.reload.reminder_at).to eq(nil)
        expect(bookmark3.reload.reminder_at).not_to eq(nil)
      end
    end
  end

  context "when this is the 6th run (so every half hour) of this job we need to ensure consistency of at_desktop reminders" do
    let(:set_at) { Time.zone.now }
    let!(:bookmark) do
      Fabricate(
        :bookmark,
        reminder_type: Bookmark.reminder_types[:at_desktop],
        reminder_at: nil,
        reminder_set_at: set_at
      )
    end
    before do
      Discourse.redis.set(Jobs::BookmarkReminderNotifications::JOB_RUN_NUMBER_KEY, 6)
      bookmark.user.update(last_seen_at: Time.zone.now - 1.minute)
    end
    context "when an at_desktop reminder is not pending in redis for a user who should have one" do
      it "puts the pending reminder into redis" do
        expect(BookmarkReminderNotificationHandler.user_has_pending_at_desktop_reminders?(bookmark.user)).to eq(false)
        subject.execute
        expect(BookmarkReminderNotificationHandler.user_has_pending_at_desktop_reminders?(bookmark.user)).to eq(true)
      end

      context "if the user has not been seen in the past 24 hours" do
        before do
          bookmark.user.update(last_seen_at: Time.zone.now - 25.hours)
        end
        it "does not put the pending reminder into redis" do
          subject.execute
          expect(BookmarkReminderNotificationHandler.user_has_pending_at_desktop_reminders?(bookmark.user)).to eq(false)
        end
      end

      context "if the at_desktop reminder is expired (set over PENDING_AT_DESKTOP_EXPIRY_DAYS days ago)" do
        let(:set_at) { Time.zone.now - (BookmarkReminderNotificationHandler::PENDING_AT_DESKTOP_EXPIRY_DAYS + 1).days }
        it "does not put the pending reminder into redis, and clears the reminder type/time" do
          expect(BookmarkReminderNotificationHandler.user_has_pending_at_desktop_reminders?(bookmark.user)).to eq(false)
          subject.execute
          expect(BookmarkReminderNotificationHandler.user_has_pending_at_desktop_reminders?(bookmark.user)).to eq(false)
          bookmark.reload
          expect(bookmark.reminder_set_at).to eq(nil)
          expect(bookmark.reminder_last_sent_at).to eq(nil)
          expect(bookmark.reminder_type).to eq(nil)
        end
      end
    end
  end
end
