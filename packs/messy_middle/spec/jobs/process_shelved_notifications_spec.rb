# frozen_string_literal: true

RSpec.describe Jobs::ProcessShelvedNotifications do
  fab!(:user) { Fabricate(:user) }
  let(:post) { Fabricate(:post) }

  it "removes all past do not disturb timings" do
    future = Fabricate(:do_not_disturb_timing, ends_at: 1.day.from_now)
    past = Fabricate(:do_not_disturb_timing, starts_at: 2.day.ago, ends_at: 1.minute.ago)

    expect { subject.execute({}) }.to change { DoNotDisturbTiming.count }.by (-1)
    expect(DoNotDisturbTiming.find_by(id: future.id)).to eq(future)
    expect(DoNotDisturbTiming.find_by(id: past.id)).to eq(nil)
  end

  it "does not process shelved_notifications when the user is in DND" do
    user.do_not_disturb_timings.create(starts_at: 2.days.ago, ends_at: 2.days.from_now)
    notification =
      Notification.create(
        read: false,
        user_id: user.id,
        topic_id: 2,
        post_number: 1,
        data: "{}",
        notification_type: 1,
      )
    expect(notification.shelved_notification).to be_present
    subject.execute({})
    expect(notification.shelved_notification).to be_present
  end

  it "processes and destroys shelved_notifications when the user leaves DND" do
    user.do_not_disturb_timings.create(starts_at: 2.days.ago, ends_at: 2.days.from_now)
    notification =
      Notification.create(
        read: false,
        user_id: user.id,
        topic_id: 2,
        post_number: 1,
        data: "{}",
        notification_type: 1,
      )
    user.do_not_disturb_timings.last.update(ends_at: 1.days.ago)

    expect(notification.shelved_notification).to be_present
    subject.execute({})
    expect { notification.shelved_notification.reload }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
