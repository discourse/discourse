# frozen_string_literal: true

RSpec.describe DiscourseEvents::Livestream::NotificationPause do
  subject(:notification_pause) { described_class.new(user:, key: SecureRandom.uuid) }

  fab!(:user)

  # Leaving can overlap the request that starts the pause, so the two must
  # take turns rather than each checking state the other is about to change.
  it "starts and ends under the same lock" do
    lock_names = []
    allow(DistributedMutex).to receive(:synchronize).and_wrap_original do |original, name, &block|
      lock_names << name
      original.call(name, &block)
    end

    notification_pause.start(ends_at: 1.hour.from_now)
    notification_pause.end

    expect(lock_names.size).to eq(2)
    expect(lock_names.uniq.size).to eq(1)
  end
end
