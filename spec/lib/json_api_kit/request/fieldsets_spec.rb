# frozen_string_literal: true

RSpec.describe JsonApiKit::Request::Fieldsets do
  subject(:fieldsets) { described_class.parse(raw) }

  let(:raw) { { "topics" => "title,postedDate" } }
  let(:attributes) { { "title" => "A", "postedDate" => "2026-08-01", "postedTime" => "00:00:00" } }

  describe ".parse" do
    subject(:kept_attributes) { fieldsets.keep("topics", attributes) }

    it "returns fieldsets that keep the attributes a list holds" do
      expect(kept_attributes).to eq("title" => "A", "postedDate" => "2026-08-01")
    end

    context "when a fieldset is an array" do
      let(:raw) { { "topics" => %w[postedDate] } }

      it "returns fieldsets that keep the attributes it holds" do
        expect(kept_attributes).to eq("postedDate" => "2026-08-01")
      end
    end

    context "when a fieldset is empty" do
      let(:raw) { { "topics" => "" } }

      it "returns fieldsets that keep no attribute" do
        expect(kept_attributes).to be_empty
      end
    end

    context "without fieldsets" do
      let(:raw) { nil }

      it "returns fieldsets that keep every attribute" do
        expect(kept_attributes).to eq(attributes)
      end
    end
  end

  describe "#keep" do
    subject(:kept_attributes) { fieldsets.keep(type, attributes) }

    let(:type) { "topics" }

    it "returns the attributes the fieldset of that type holds" do
      expect(kept_attributes).to eq("title" => "A", "postedDate" => "2026-08-01")
    end

    it "keeps the order of the attributes" do
      expect(
        described_class.parse("topics" => "postedDate,title").keep(type, attributes).keys,
      ).to eq(%w[title postedDate])
    end

    context "when no fieldset holds the type" do
      let(:type) { "users" }

      it "returns every attribute" do
        expect(kept_attributes).to eq(attributes)
      end
    end
  end
end
