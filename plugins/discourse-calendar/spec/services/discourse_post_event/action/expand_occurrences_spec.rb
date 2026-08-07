# frozen_string_literal: true

RSpec.describe DiscoursePostEvent::Action::ExpandOccurrences do
  describe ".call" do
    subject(:action) { described_class.call(event:, after:, before:, limit:) }

    let(:after) { Time.zone.parse("2030-01-01 00:00:00 UTC") }
    let(:before) { nil }
    let(:limit) { described_class::MAX_LIMIT + 1 }
    let(:event) { instance_double(DiscoursePostEvent::Event, recurring?: true) }

    before do
      next_occurrence_starts_at = Time.zone.parse("2030-01-01 09:00:00 UTC")

      allow(event).to receive(:calculate_next_occurrence_from) do
        starts_at = next_occurrence_starts_at
        next_occurrence_starts_at += 1.day
        { starts_at:, ends_at: starts_at + 1.hour }
      end
    end

    it "caps recurring occurrences at the maximum limit" do
      expect(action[:occurrences].size).to eq(described_class::MAX_LIMIT)
    end
  end

  describe ".call with current_occurrence_only" do
    subject(:action) do
      described_class.call(event:, after:, before:, current_occurrence_only: true)
    end

    let(:current_starts_at) { Time.zone.parse("2030-01-05 09:00:00 UTC") }
    let(:current_ends_at) { Time.zone.parse("2030-01-05 10:00:00 UTC") }
    let(:event) do
      instance_double(
        DiscoursePostEvent::Event,
        recurring?: true,
        starts_at: current_starts_at,
        ends_at: current_ends_at,
      )
    end

    context "when the current occurrence is within the window" do
      let(:after) { Time.zone.parse("2030-01-01 00:00:00 UTC") }
      let(:before) { Time.zone.parse("2030-02-01 00:00:00 UTC") }

      it "returns only the current occurrence instead of the whole series" do
        expect(action[:occurrences]).to eq(
          [{ starts_at: current_starts_at, ends_at: current_ends_at }],
        )
      end
    end

    context "when the current occurrence is before the requested window" do
      let(:after) { Time.zone.parse("2030-02-01 00:00:00 UTC") }
      let(:before) { Time.zone.parse("2030-03-01 00:00:00 UTC") }

      it "returns no occurrences" do
        expect(action[:occurrences]).to be_empty
      end
    end

    context "when the current occurrence is after the requested window" do
      let(:after) { Time.zone.parse("2029-11-01 00:00:00 UTC") }
      let(:before) { Time.zone.parse("2029-12-01 00:00:00 UTC") }

      it "returns no occurrences" do
        expect(action[:occurrences]).to be_empty
      end
    end
  end
end
