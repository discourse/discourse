# frozen_string_literal: true

RSpec.describe JsonApiKit::Anchoring do
  subject(:anchoring) { described_class.for(anchor) }

  let(:anchor) { { id: 12 } }

  describe ".for" do
    it "returns the key as the name" do
      expect(anchoring.name).to eq("id")
    end

    it "returns the value beside it" do
      expect(anchoring.value).to eq(12)
    end

    context "when the key is a string" do
      let(:anchor) { { "id" => 12 } }

      it "returns the same name" do
        expect(anchoring.name).to eq("id")
      end
    end

    context "when the hash holds two keys" do
      let(:anchor) { { id: 12, created_at: "2026-08-20" } }

      it "returns the first pair" do
        expect(anchoring).to have_attributes(name: "id", value: 12)
      end
    end

    context "when the anchor is a symbol" do
      let(:anchor) { :first_unread }

      it "returns it as the name" do
        expect(anchoring.name).to eq("first_unread")
      end

      it "returns no value" do
        expect(anchoring.value).to be_nil
      end
    end

    context "when the anchor is nil" do
      let(:anchor) { nil }

      it "returns nothing" do
        expect(anchoring).to be_nil
      end
    end
  end
end
