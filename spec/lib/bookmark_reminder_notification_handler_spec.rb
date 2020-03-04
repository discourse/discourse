# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BookmarkReminderNotificationHandler do
  subject { described_class }

  FakeRequest = Struct.new(:user_agent)

  fab!(:user) { Fabricate(:user) }
  let(:request) { FakeRequest.new(user_agent) }
  let(:last_used_key) { "last_used_device_user_#{user.id}" }

  before do
    SiteSetting.enable_bookmarks_with_reminders = true
    Discourse.redis.del(last_used_key)
  end

  context "when the user agent is for mobile" do
    let(:user_agent) { "Mozilla/5.0 (iPhone; CPU iPhone OS 9_1 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13B143 Safari/601.1" }
    it "does not attempt to send any reminders but still sets last used device" do
      DistributedMutex.expects(:synchronize).never
      send_reminder
      expect(last_used_device).to eq("iphone")
    end
  end

  context "when the user agent is for desktop" do
    let(:user_agent) { "Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.90 Safari/537.36" }
    fab!(:reminder) do
      Fabricate(
        :bookmark,
        user: user,
        reminder_type: Bookmark.reminder_types[:at_desktop],
        reminder_at: nil
      )
    end

    context "if the last used device is also desktop (does not have to be same desktop)" do
      before do
        set_last_used_device("linux")
      end

      it "does not attempt to set any reminders but still sets last used device" do
        DistributedMutex.expects(:synchronize).never
        send_reminder
        expect(last_used_device).to eq("windows")
      end
    end

    context "if the last used device is a mobile device" do
      before do
        set_last_used_device("iphone")
      end

      it "sends the notification to the user" do
        send_reminder
        expect(Notification.where(user: user, notification_type: Notification.types[:bookmark_reminder]).count).to eq(1)
        expect(reminder.reload.reminder_type).to eq(nil)
      end
    end

    context "if there is no last used device" do
      it "sends the notification to the user" do
        send_reminder
        expect(Notification.where(user: user, notification_type: Notification.types[:bookmark_reminder]).count).to eq(1)
        expect(reminder.reload.reminder_type).to eq(nil)
      end
    end

    context "when enable bookmarks with reminders is disabled" do
      before do
        SiteSetting.enable_bookmarks_with_reminders = false
      end

      it "does nothing" do
        BrowserDetection.expects(:device).never
        send_reminder
      end
    end
  end

  def send_reminder
    subject.send_at_desktop_reminder(user: user, request: request)
  end

  def last_used_device
    Discourse.redis.get(last_used_key)
  end

  def set_last_used_device(device)
    Discourse.redis.set(last_used_key, device)
  end
end
