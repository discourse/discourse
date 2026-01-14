# frozen_string_literal: true

RSpec.describe ::Jobs::NotifyAdminsOfProblems do
  fab!(:admin)

  it "creates notification when problems persist for at least 2 days" do
    ProblemCheckTracker.create!(
      identifier: "bad_favicon_url",
      last_success_at: 3.days.ago,
      last_problem_at: 1.hour.ago,
    )

    expect { described_class.new.execute({}) }.to change { Notification.count }.by(1)
  end

  it "does not replace old notification created in last 7 days" do
    ProblemCheckTracker.create!(
      identifier: "bad_favicon_url",
      last_success_at: 3.days.ago,
      last_problem_at: 1.hour.ago,
    )
    old_notification =
      Notification.create!(
        notification_type: Notification.types[:admin_problems],
        user_id: admin.id,
        data: "{}",
      )

    expect { described_class.new.execute({}) }.not_to change { Notification.count }
    new_notification = Notification.last

    expect(old_notification.id).to equal(new_notification.id)
  end

  it "replaces old notification created more than 7 days ago" do
    ProblemCheckTracker.create!(
      identifier: "bad_favicon_url",
      last_success_at: 3.days.ago,
      last_problem_at: 1.hour.ago,
    )
    old_notification =
      Notification.create!(
        notification_type: Notification.types[:admin_problems],
        user_id: admin.id,
        data: "{}",
        created_at: 2.weeks.ago,
      )

    expect { described_class.new.execute({}) }.not_to change { Notification.count }
    new_notification = Notification.last

    expect(old_notification.id).not_to equal(new_notification.id)
  end
end
