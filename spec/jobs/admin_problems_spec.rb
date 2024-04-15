# frozen_string_literal: true

RSpec.describe ::Jobs::AdminProblems do
  fab!(:admin)

  it "creates notification when problems persist for at least 2 days" do
    Discourse.redis.setex(AdminDashboardData.problems_started_key, 14.days.to_i, Time.zone.now.to_s)
    expect { described_class.new.execute({}) }.not_to change { Notification.count }

    Discourse.redis.setex(AdminDashboardData.problems_started_key, 14.days.to_i, 3.days.ago)
    expect { described_class.new.execute({}) }.to change { Notification.count }.by(1)
  end

  it "does not replace old notification created in last 7 days" do
    Discourse.redis.setex(AdminDashboardData.problems_started_key, 14.days.to_i, 3.days.ago)
    expect { described_class.new.execute({}) }.to change { Notification.count }.by(1)
    old_notification = Notification.last

    expect { described_class.new.execute({}) }.not_to change { Notification.count }
    new_notification = Notification.last

    expect(old_notification.id).to equal(new_notification.id)
  end

  it "replace old notification created more than 7 days ago" do
    Discourse.redis.setex(AdminDashboardData.problems_started_key, 14.days.to_i, 13.days.ago)
    freeze_time 10.days.ago do
      expect { described_class.new.execute({}) }.to change { Notification.count }.by(1)
    end
    old_notification = Notification.last

    expect { described_class.new.execute({}) }.not_to change { Notification.count }
    new_notification = Notification.last

    expect(old_notification.id).not_to equal(new_notification.id)
  end
end
