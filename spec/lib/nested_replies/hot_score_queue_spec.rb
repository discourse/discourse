# frozen_string_literal: true

RSpec.describe NestedReplies::HotScoreQueue do
  before { described_class.clear }
  after { described_class.clear }

  it "deduplicates topics and pops the oldest demand first" do
    expect(described_class.enqueue(10, requested_at: 2.minutes.ago)).to eq(:queued)
    expect(described_class.enqueue(20, requested_at: 1.minute.ago)).to eq(:queued)
    expect(described_class.enqueue(10)).to eq(:duplicate)
    expect(described_class.oldest_age).to be >= 2.minutes.to_f
    expect([described_class.pop, described_class.pop, described_class.pop]).to eq([10, 20, nil])
  end

  it "caps pending work and honors a failure cooldown" do
    stub_const(described_class, :MAX_PENDING_TOPICS, 1) do
      expect(described_class.enqueue(10)).to eq(:queued)
      expect(described_class.enqueue(20)).to eq(:full)
      expect(described_class.pop).to eq(10)

      described_class.cooldown(10, duration: 1.hour)

      expect(described_class.enqueue(10)).to eq(:cooldown)
      expect(described_class.enqueue(10, requested_at: 2.hours.from_now)).to eq(:queued)
    end
  end

  it "discards obsolete demand before it can run after a long pause" do
    described_class.enqueue(10, requested_at: 2.hours.ago)

    expect(described_class.pop).to be_nil
  end

  it "treats invalid input and Redis failure as safe cache misses" do
    allow(described_class::ENQUEUE_SCRIPT).to receive(:eval).and_raise(
      Redis::ConnectionError,
      "unavailable",
    )

    expect(described_class.enqueue(nil)).to eq(:invalid)
    expect(described_class.enqueue(10)).to eq(:unavailable)
  end
end
