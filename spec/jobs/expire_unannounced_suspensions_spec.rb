# frozen_string_literal: true

RSpec.describe Jobs::ExpireUnannouncedSuspensions do
  fab!(:admin)
  fab!(:user)

  def suspend(until_time)
    UserSuspender.new(user, suspended_till: until_time, reason: "spam", by_user: admin).suspend
  end

  it "announces once a suspension whose expiry job never ran", :aggregate_failures do
    suspend(1.hour.from_now)
    freeze_time 2.hours.from_now

    events =
      DiscourseEvent.track_events(:user_unsuspended) { 2.times { described_class.new.execute({}) } }

    expect(events.sole[:params].sole).to include(user:, by_user: Discourse.system_user)
  end

  it "leaves current and already announced suspensions alone", :aggregate_failures do
    suspend(1.hour.from_now)

    expect { described_class.new.execute({}) }.not_to change { UserHistory.count }

    freeze_time 2.hours.from_now
    Jobs::UserSuspensionExpired.new.execute(
      user_id: user.id,
      suspended_at: user.suspended_at.iso8601(UserSuspender::TIMESTAMP_PRECISION),
      suspended_till: user.suspended_till.iso8601(UserSuspender::TIMESTAMP_PRECISION),
    )

    events = DiscourseEvent.track_events(:user_unsuspended) { described_class.new.execute({}) }
    expect(events).to be_empty
  end
end
