# frozen_string_literal: true

require "rails_helper"

describe Jobs::ProcessShelvedNotifications do
  fab!(:user) { Fabricate(:user) }
  let(:post) { Fabricate(:post) }
  let(:notification) { Notification.create!(read: false, user_id: user.id, topic_id: post.topic_id, post_number: post.post_number, data: '[]', notification_type: Notification.types[:mentioned], created_at: 0.days.from_now)
  }
  # it "automatically marks the notification as high priority if it is a high priority type" do
    # notif = Notification.create(user: user, notification_type: Notification.types[:bookmark_reminder], data: {})
  # end

  it "removes all past do not disturb timings" do
    future = Fabricate(:do_not_disturb_timing, ends_at: Time.now + 1.day)
    past = Fabricate(:do_not_disturb_timing, starts_at: Time.zone.now - 2.day, ends_at: 1.minute.ago)

    expect {
      subject.execute({})
    }.to change{ DoNotDisturbTiming.count }.by (-1)
    expect(DoNotDisturbTiming.find_by(id: future.id)).to eq(future)
    expect(DoNotDisturbTiming.find_by(id: past.id)).to eq(nil)
  end
end
