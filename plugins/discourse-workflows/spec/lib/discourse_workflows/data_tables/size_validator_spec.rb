# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTables::SizeValidator do
  let(:time_1) { Time.zone.parse("2026-03-27 12:00:00 UTC") }
  let(:time_2) { time_1 + 0.5 }
  let(:time_3) { time_1 + 5.001 }

  around do |example|
    stub_const(described_class, :MAX_TOTAL_SIZE_BYTES, 100.megabytes) { example.run }
  end

  before { described_class.reset! }

  after { described_class.reset! }

  describe ".within_limit?" do
    it "returns true when usage is below the limit" do
      allow(DiscourseWorkflows::DataTables::Storage).to receive(:total_size_bytes).and_return(
        50.megabytes,
      )

      expect(described_class.within_limit?(now: time_1)).to be(true)
    end

    it "returns false when usage matches the limit" do
      allow(DiscourseWorkflows::DataTables::Storage).to receive(:total_size_bytes).and_return(
        100.megabytes,
      )

      expect(described_class.within_limit?(now: time_1)).to be(false)
    end

    it "reuses the cached size within the cache window" do
      allow(DiscourseWorkflows::DataTables::Storage).to receive(:total_size_bytes).and_return(
        50.megabytes,
      )

      described_class.within_limit?(now: time_1)
      described_class.within_limit?(now: time_2)

      expect(DiscourseWorkflows::DataTables::Storage).to have_received(:total_size_bytes).once
    end

    it "refreshes the cached size after the cache window expires" do
      allow(DiscourseWorkflows::DataTables::Storage).to receive(:total_size_bytes).and_return(
        50.megabytes,
      )

      described_class.within_limit?(now: time_1)
      described_class.within_limit?(now: time_3)

      expect(DiscourseWorkflows::DataTables::Storage).to have_received(:total_size_bytes).twice
    end
  end

  describe ".reset!" do
    it "clears the cached size immediately" do
      allow(DiscourseWorkflows::DataTables::Storage).to receive(:total_size_bytes).and_return(
        50.megabytes,
      )

      described_class.within_limit?(now: time_1)
      described_class.reset!
      described_class.within_limit?(now: time_2)

      expect(DiscourseWorkflows::DataTables::Storage).to have_received(:total_size_bytes).twice
    end
  end
end
