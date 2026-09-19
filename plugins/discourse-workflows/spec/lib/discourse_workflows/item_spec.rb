# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Item do
  describe ".wrap" do
    it "wraps a hash with stringified keys" do
      expect(described_class.wrap(name: "Alice")).to eq("json" => { "name" => "Alice" })
    end

    it "deep-stringifies nested keys" do
      expect(described_class.wrap(outer: { inner: "val" })).to eq(
        "json" => {
          "outer" => {
            "inner" => "val",
          },
        },
      )
    end

    it "freezes the inner json hash" do
      expect(described_class.wrap("key" => "value")["json"]).to be_frozen
    end

    it "maps over an array of hashes" do
      expect(described_class.wrap([{ "name" => "A" }, { "name" => "B" }])).to eq(
        [{ "json" => { "name" => "A" } }, { "json" => { "name" => "B" } }],
      )
    end

    it "adds compatible pairedItem metadata" do
      expect(described_class.wrap({ "name" => "A" }, paired_item: { item: 1 })).to eq(
        "json" => {
          "name" => "A",
        },
        "pairedItem" => {
          "item" => 1,
        },
      )
    end

    it "normalizes shorthand pairedItem metadata" do
      expect(described_class.wrap({ "name" => "A" }, paired_item: 1)).to include(
        "pairedItem" => {
          "item" => 1,
        },
      )
    end

    it "raises when given something other than a Hash or Array" do
      expect { described_class.wrap(nil) }.to raise_error(ArgumentError)
      expect { described_class.wrap("string") }.to raise_error(ArgumentError)
    end
  end

  describe ".normalize_items" do
    it "wraps plain objects as json items" do
      expect(described_class.normalize_items([{ name: "Ada" }])).to eq(
        [{ "json" => { "name" => "Ada" } }],
      )
    end

    it "preserves item-shaped objects and normalizes pairedItem" do
      expect(described_class.normalize_items([{ json: { name: "Ada" }, pairedItem: 0 }])).to eq(
        [{ "json" => { "name" => "Ada" }, "pairedItem" => { "item" => 0 } }],
      )
    end

    it "raises when json item and plain object formats are mixed" do
      expect { described_class.normalize_items([{ json: { id: 1 } }, { id: 2 }]) }.to raise_error(
        described_class::InconsistentItemFormatError,
        described_class::INCONSISTENT_ITEM_FORMAT_MESSAGE,
      )
    end

    it "treats binary as a regular JSON field" do
      expect(described_class.normalize_items([{ binary: {} }, { id: 2 }])).to eq(
        [{ "json" => { "binary" => {} } }, { "json" => { "id" => 2 } }],
      )
    end

    it "raises when item-shaped and plain binary field formats are mixed" do
      expect {
        described_class.normalize_items([{ json: { id: 1 } }, { binary: {} }])
      }.to raise_error(
        described_class::InconsistentItemFormatError,
        described_class::INCONSISTENT_ITEM_FORMAT_MESSAGE,
      )
    end
  end
end
