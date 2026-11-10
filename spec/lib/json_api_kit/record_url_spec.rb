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
    subject(:address) { url.relationship(name).to_s }

    let(:name) { "posts" }

    it { is_expected.to eq("https://example.com/api/topics/5/relationships/posts") }

    context "when the declared name has several words" do
      let(:name) { "valid_groups" }

      it "uses a kebab-case path segment" do
        expect(address).to eq("https://example.com/api/topics/5/relationships/valid-groups")
      end
    end
  end

  describe "#related" do
    subject(:address) { url.related(name).to_s }

    let(:name) { "posts" }

    it { is_expected.to eq("https://example.com/api/topics/5/posts") }

    context "when the declared name has several words" do
      let(:name) { "valid_groups" }

      it "uses a kebab-case path segment" do
        expect(address).to eq("https://example.com/api/topics/5/valid-groups")
      end
    end
  end
end
