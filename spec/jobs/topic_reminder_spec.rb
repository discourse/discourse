require 'rails_helper'

describe Jobs::TopicReminder do
  let(:admin) { Fabricate(:admin) }
  let(:topic) { Fabricate(:topic, topic_status_updates: [
    Fabricate(:topic_status_update, user: admin, status_type: TopicStatusUpdate.types[:reminder])
  ]) }

  before do
    SiteSetting.queue_jobs = true
  end

  it "should be able to create a reminder" do
    topic
    topic_status_update = topic.topic_status_update(admin)
    Timecop.freeze(1.day.from_now) do
      expect {
        described_class.new.execute(topic_status_update_id: topic_status_update.id)
      }.to change { Notification.count }.by(1)
      expect( admin.notifications.where(notification_type: Notification.types[:topic_reminder]).first&.topic_id ).to eq(topic.id)
      expect( TopicStatusUpdate.where(id: topic_status_update.id).first ).to be_nil
    end
  end

  it "does nothing if it was trashed before the scheduled time" do
    topic
    topic_status_update = topic.topic_status_update(admin)
    topic_status_update.trash!(Discourse.system_user)
    Timecop.freeze(1.day.from_now) do
      expect {
        described_class.new.execute(topic_status_update_id: topic_status_update.id)
      }.to_not change { Notification.count }
    end
  end

  it "does nothing if job runs too early" do
    topic
    topic_status_update = topic.topic_status_update(admin)
    topic_status_update.update_attribute(:execute_at, 8.hours.from_now)
    Timecop.freeze(6.hours.from_now) do
      expect {
        described_class.new.execute(topic_status_update_id: topic_status_update.id)
      }.to_not change { Notification.count }
    end
  end

  it "does nothing if topic was deleted" do
    topic
    topic_status_update = topic.topic_status_update(admin)
    topic.trash!
    Timecop.freeze(1.day.from_now) do
      expect {
        described_class.new.execute(topic_status_update_id: topic_status_update.id)
      }.to_not change { Notification.count }
    end
  end

end
