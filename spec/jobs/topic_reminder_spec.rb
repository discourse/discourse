# frozen_string_literal: true

require 'rails_helper'

describe Jobs::TopicReminder do
  fab!(:admin) { Fabricate(:admin) }

  fab!(:topic) do
    Fabricate(:topic_timer,
      user: admin,
      status_type: TopicTimer.types[:reminder]
    ).topic
  end

  it "should be able to create a reminder" do
    topic_timer = topic.topic_timers.first
    freeze_time 1.day.from_now

    expect {
      described_class.new.execute(topic_timer_id: topic_timer.id)
    }.to change { Notification.count }.by(1)
    expect(admin.notifications.where(notification_type: Notification.types[:topic_reminder]).first&.topic_id).to eq(topic.id)
    expect(TopicTimer.where(id: topic_timer.id).first).to be_nil
  end

  it "does nothing if it was trashed before the scheduled time" do
    topic_timer = topic.topic_timers.first
    topic_timer.trash!(Discourse.system_user)

    freeze_time(1.day.from_now)

    expect {
      described_class.new.execute(topic_timer_id: topic_timer.id)
    }.to_not change { Notification.count }
  end

  it "does nothing if job runs too early" do
    topic_timer = topic.topic_timers.first
    topic_timer.update_attribute(:execute_at, 8.hours.from_now)

    freeze_time(6.hours.from_now)

    expect {
      described_class.new.execute(topic_timer_id: topic_timer.id)
    }.to_not change { Notification.count }
  end

  it "does nothing if topic was deleted" do
    topic_timer = topic.topic_timers.first
    topic.trash!

    freeze_time(1.day.from_now)

    expect {
      described_class.new.execute(topic_timer_id: topic_timer.id)
    }.to_not change { Notification.count }
  end

end
