# frozen_string_literal: true

RSpec.describe ::Jobs::DashboardStats do
  fab!(:admin) { Fabricate(:admin) }

  it "creates group notification when problems are persistent for 2 days" do
    Discourse.redis.setex(AdminDashboardData.problems_started_key, 14.days.to_i, Time.zone.now.to_s)
    expect { described_class.new.execute({}) }.not_to change { Notification.count }

    Discourse.redis.setex(AdminDashboardData.problems_started_key, 14.days.to_i, 3.days.ago)
    expect { described_class.new.execute({}) }.to change { Notification.count }.by(1)
  end

  it "replaces old notification" do
    Discourse.redis.setex(AdminDashboardData.problems_started_key, 14.days.to_i, 3.days.ago)
    expect { described_class.new.execute({}) }.to change { Notification.count }.by(1)
    old_notification = Notification.last

    described_class.new.execute({})
    new_notification = Notification.last

    expect(old_notification.id).not_to equal(new_notification.id)
  end
end
