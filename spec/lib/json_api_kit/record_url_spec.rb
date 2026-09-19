# frozen_string_literal: true

RSpec.describe JsonApiKit::RecordUrl do
  subject(:url) { described_class.new(base, record) }

  let(:base) { "https://example.com/api" }
  let(:namespace) { nil }
  let(:record) { instance_double(JsonApiKit::Record, namespace:, type: "topics", id: "5") }

  describe "#to_s" do
    subject(:address) { url.to_s }

    it { is_expected.to eq("https://example.com/api/topics/5") }

    context "with a namespace" do
      let(:namespace) { "data-explorer" }

      it { is_expected.to eq("https://example.com/api/data-explorer/topics/5") }
    end
  end

  describe "#relationship" do
    subject(:address) { url.relationship("posts").to_s }

    it { is_expected.to eq("https://example.com/api/topics/5/relationships/posts") }
  end

  describe "#related" do
    subject(:address) { url.related("posts").to_s }

    it { is_expected.to eq("https://example.com/api/topics/5/posts") }
  end
end
