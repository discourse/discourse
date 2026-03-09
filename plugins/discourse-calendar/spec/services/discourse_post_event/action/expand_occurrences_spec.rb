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
end
