# frozen_string_literal: true

RSpec.describe JsonApiKit::Declarations::Anchor do
  describe ".for" do
    subject(:anchor) { described_class.for(:created_at) }

    it "returns an anchor on an attribute" do
      expect(anchor).to be_a(described_class::Attribute)
    end

    it "gives it the name a request anchors by" do
      expect(anchor.name).to eq("created_at")
    end

    context "when the name is the primary key" do
      subject(:anchor) { described_class.for(:id) }

      it "returns an anchor on the identity" do
        expect(anchor).to be_a(described_class::Identity)
      end
    end

    context "when the resource declares how to calculate the anchor" do
      subject(:anchor) { described_class.for(:mine) { |topics, _guardian| topics } }

      it "returns a computed anchor" do
        expect(anchor).to be_a(described_class::Computed)
      end
    end
  end

  describe described_class::NoRow do
    subject(:error) { described_class.new("created_at", Time.utc(2026, 8, 3)) }

    describe "#title" do
      it "returns the title of the error" do
        expect(error.title).to eq("No row for the anchor")
      end
    end

    describe "#source" do
      it "points at that anchor" do
        expect(error.source).to eq(parameter: "page[anchor][created_at]")
      end
    end
  end
end
