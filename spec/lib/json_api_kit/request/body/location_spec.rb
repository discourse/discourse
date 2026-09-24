# frozen_string_literal: true

RSpec.describe JsonApiKit::Request::Body::Location do
  subject(:location) { described_class.new(document, path) }

  let(:document) { { "data" => { "type" => "topics", "attributes" => { "title" => nil } } } }
  let(:path) { %w[data type] }

  describe ".for" do
    subject(:location) { described_class.for(attribute, document:) }

    let(:attribute) { :"data.type" }

    it "locates the contract attribute" do
      expect(location.value).to eq("topics")
    end

    context "when the attribute is base" do
      let(:attribute) { :base }

      it "locates the whole document" do
        expect(location.value).to equal(document)
      end
    end
  end

  describe "#value" do
    it "reads the submitted value" do
      expect(location.value).to eq("topics")
    end

    context "when a parent is a scalar" do
      let(:document) { { "data" => false } }

      it "returns no value" do
        expect(location.value).to be_nil
      end
    end
  end

  describe "#supplied?" do
    it { is_expected.to be_supplied }

    context "when the value is null" do
      let(:path) { %w[data attributes title] }

      it { is_expected.to be_supplied }
    end

    context "when the member is omitted" do
      let(:path) { %w[data id] }

      it { is_expected.not_to be_supplied }
    end

    context "when a parent is omitted" do
      let(:document) { {} }

      it { is_expected.not_to be_supplied }
    end

    context "when the document is null" do
      let(:document) { nil }
      let(:path) { [] }

      it { is_expected.to be_supplied }
    end
  end

  describe "#nearest_existing" do
    it "retains a supplied location" do
      expect(location.nearest_existing).to equal(location)
    end

    context "when the member is omitted" do
      let(:path) { %w[data id] }

      it "locates the parent" do
        expect(location.nearest_existing.pointer).to eq("/data")
      end
    end

    context "when a parent is null" do
      let(:document) { { "data" => nil } }

      it "locates the explicit null" do
        expect(location.nearest_existing.pointer).to eq("/data")
      end
    end

    context "when data is omitted" do
      let(:document) { {} }

      it "locates the document" do
        expect(location.nearest_existing.pointer).to eq("")
      end
    end
  end

  describe "#pointer" do
    it "encodes the member path" do
      expect(location.pointer).to eq("/data/type")
    end

    context "when member names contain pointer characters" do
      let(:path) { %w[data attributes a~/b.c] }

      it "escapes each complete member name" do
        expect(location.pointer).to eq("/data/attributes/a~0~1b.c")
      end
    end
  end
end
