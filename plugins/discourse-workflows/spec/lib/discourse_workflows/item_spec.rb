# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Item do
  describe "#initialize" do
    it "stringifies keys" do
      item = described_class.new(foo: "bar")
      expect(item.json).to eq("foo" => "bar")
    end

    it "deep-stringifies nested keys" do
      item = described_class.new(outer: { inner: "val" })
      expect(item.json).to eq("outer" => { "inner" => "val" })
    end

    it "freezes the json hash" do
      item = described_class.new("key" => "value")
      expect(item.json).to be_frozen
    end
  end

  describe "#to_h" do
    it "returns the canonical item hash shape" do
      item = described_class.new("name" => "test")
      expect(item.to_h).to eq({ "json" => { "name" => "test" } })
    end
  end

  describe ".wrap" do
    it "returns an existing Item unchanged" do
      original = described_class.new("x" => 1)
      expect(described_class.wrap(original)).to be(original)
    end

    it "wraps a plain hash as item json" do
      item = described_class.wrap("name" => "Alice")
      expect(item.json).to eq("name" => "Alice")
    end

    it "unwraps an already-wrapped hash" do
      item = described_class.wrap("json" => { "name" => "Bob" })
      expect(item.json).to eq("name" => "Bob")
    end

    it "handles non-hash input" do
      item = described_class.wrap(nil)
      expect(item.json).to eq({})
    end
  end

  describe ".wrap_array" do
    it "converts an array of hashes to item hashes" do
      result = described_class.wrap_array([{ "name" => "A" }, { "name" => "B" }])
      expect(result).to eq([{ "json" => { "name" => "A" } }, { "json" => { "name" => "B" } }])
    end

    it "handles already-wrapped items" do
      result = described_class.wrap_array([{ "json" => { "x" => 1 } }])
      expect(result).to eq([{ "json" => { "x" => 1 } }])
    end

    it "handles nil input" do
      expect(described_class.wrap_array(nil)).to eq([])
    end
  end
end
