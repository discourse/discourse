# frozen_string_literal: true

RSpec.describe BrowserPageviewEntryUrlDirtyDate do
  it "retains a date dirtied again after maintenance takes its snapshot" do
    date = Date.new(2026, 5, 12)
    described_class.mark!([[date, "session-1"]])
    snapshot = described_class.snapshot

    described_class.mark!([[date, "session-1"]])
    described_class.clear!(snapshot)

    expect(described_class.pluck(:date, :generation)).to eq([[date, 2]])
  end

  it "tracks same-day sessions in independent buckets" do
    date = Date.new(2026, 5, 12)
    described_class.mark!([[date, "session-1"], [date, "session-2"]])
    snapshot = described_class.snapshot

    expect(described_class.distinct.count(:bucket)).to eq(2)

    described_class.mark!([[date, "session-1"]])
    described_class.clear!(snapshot)

    expect(described_class.pluck(:bucket, :generation)).to eq(
      [[Zlib.crc32("session-1") % described_class::BUCKET_COUNT, 2]],
    )
  end

  it "ignores events without a session" do
    described_class.mark!([[Date.new(2026, 5, 12), nil]])

    expect(described_class).not_to exist
  end
end
