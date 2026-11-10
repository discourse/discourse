# frozen_string_literal: true

RSpec.describe DiscourseEvents::Livestream::NotificationPause do
  subject(:notification_pause) { described_class.new(user:, key: SecureRandom.uuid) }

  fab!(:user)

  let(:ends_at) { 1.hour.from_now }

  describe "#start" do
    it "pauses notifications until the given time" do
      expect(notification_pause.start(ends_at:)).to have_attributes(user:)
      expect(user.reload.do_not_disturb_until).to eq_time(ends_at)
    end

    it "does nothing once the pause has been ended" do
      notification_pause.end

      expect(notification_pause.start(ends_at:)).to be_nil
      expect(user.reload.do_not_disturb?).to eq(false)
    end
  end

  describe "#end" do
    it "ends the pause it started and nothing else" do
      own_pause = Fabricate(:do_not_disturb_timing, user:, ends_at: 1.day.from_now)
      notification_pause.start(ends_at:)

      notification_pause.end

      expect(user.do_not_disturb_timings).to contain_exactly(own_pause)
    end
  end

  # Leaving can overlap the request that starts the pause, so the two must
  # take turns rather than each checking state the other is about to change.
  it "starts and ends under the same lock" do
    lock_names = []
    allow(DistributedMutex).to receive(:synchronize).and_wrap_original do |original, name, &block|
      lock_names << name
      original.call(name, &block)
    end

    notification_pause.start(ends_at:)
    notification_pause.end

    expect(lock_names.size).to eq(2)
    expect(lock_names.uniq.size).to eq(1)
  end
end
