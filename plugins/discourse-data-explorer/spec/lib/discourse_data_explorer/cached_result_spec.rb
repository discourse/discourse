# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::CachedResult do
  subject(:result) { described_class.new(identity:, attributes:) }

  let(:identity) do
    DiscourseDataExplorer::QueryResultCache::Key.new(
      query_id: "1",
      visibility: "admin",
      digest: "a" * 64,
    )
  end
  let(:attributes) { { "rows" => [[1]] } }

  describe "#hash" do
    before { allow(attributes).to receive(:hash).and_call_original }

    it "hashes the result without hashing its payload" do
      result.hash

      expect(attributes).not_to have_received(:hash)
    end
  end

  describe "#fresh?" do
    let(:now) { Time.utc(2026, 10, 29, 12) }
    let(:max_age) { 1.hour }
    let(:cached_at) { 30.minutes.ago.iso8601 }
    let(:attributes) { super().merge("cached_at" => cached_at) }

    before { freeze_time(now) }

    it { is_expected.to be_fresh(max_age:) }

    context "when the age matches the limit" do
      let(:cached_at) { 1.hour.ago.iso8601 }

      it { is_expected.to be_fresh(max_age:) }
    end

    context "when the result exceeds the maximum age" do
      let(:cached_at) { (1.hour + 1.second).ago.iso8601 }

      it { is_expected.not_to be_fresh(max_age:) }
    end

    context "when the timestamp is malformed" do
      let(:cached_at) { "not-a-timestamp" }

      it { is_expected.not_to be_fresh(max_age:) }
    end

    context "when the timestamp is missing" do
      let(:attributes) { super().except("cached_at") }

      it { is_expected.not_to be_fresh(max_age:) }
    end

    context "when no maximum age is supplied" do
      let(:attributes) { super().except("cached_at") }

      it { is_expected.to be_fresh }
    end
  end

  describe "Hash lookup" do
    subject(:lookup) { index.fetch(other_result, :missing) }

    let(:index) { { result => :cached } }
    let(:other_result) { described_class.new(identity: identity.dup, attributes: other_attributes) }
    let(:other_attributes) { attributes.deep_dup }

    it "finds an equivalent result" do
      expect(lookup).to eq(:cached)
    end

    context "when the payload differs" do
      let(:other_attributes) { super().merge("rows" => [[2]]) }

      it "distinguishes results with the same identity" do
        expect(lookup).to eq(:missing)
      end
    end
  end
end
