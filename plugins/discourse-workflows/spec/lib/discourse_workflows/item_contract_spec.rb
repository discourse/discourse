# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::ItemContract do
  describe ".validate_items!" do
    it "accepts a valid items array" do
      items = [{ "json" => { "key" => "value" } }]
      expect { described_class.validate_items!(items, source: "test") }.not_to raise_error
    end

    it "accepts an empty array" do
      expect { described_class.validate_items!([], source: "test") }.not_to raise_error
    end

    it "accepts multi-item arrays" do
      items = [{ "json" => { "a" => 1 } }, { "json" => { "b" => 2 } }]
      expect { described_class.validate_items!(items, source: "test") }.not_to raise_error
    end

    it "rejects nil" do
      expect { described_class.validate_items!(nil, source: "test") }.to raise_error(
        DiscourseWorkflows::ItemContract::Error,
        /Invalid items from test/,
      )
    end

    it "rejects a hash instead of array" do
      expect { described_class.validate_items!({ "json" => {} }, source: "test") }.to raise_error(
        DiscourseWorkflows::ItemContract::Error,
      )
    end

    it "rejects items missing the json key" do
      expect { described_class.validate_items!([{ "data" => {} }], source: "test") }.to raise_error(
        DiscourseWorkflows::ItemContract::Error,
      )
    end

    it "rejects items that are not hashes" do
      expect { described_class.validate_items!(["string"], source: "test") }.to raise_error(
        DiscourseWorkflows::ItemContract::Error,
      )
    end
  end

  describe ".validate_output_arrays!" do
    it "accepts valid output arrays" do
      result = [[{ "json" => { "a" => 1 } }], [{ "json" => { "b" => 2 } }]]
      expect { described_class.validate_output_arrays!(result, source: "test") }.not_to raise_error
    end

    it "accepts empty inner arrays" do
      result = [[], [{ "json" => { "a" => 1 } }]]
      expect { described_class.validate_output_arrays!(result, source: "test") }.not_to raise_error
    end

    it "rejects non-array outer" do
      expect {
        described_class.validate_output_arrays!({ "true" => [] }, source: "test")
      }.to raise_error(DiscourseWorkflows::ItemContract::Error)
    end

    it "rejects non-array inner" do
      expect {
        described_class.validate_output_arrays!([{ "json" => {} }], source: "test")
      }.to raise_error(DiscourseWorkflows::ItemContract::Error)
    end

    it "validates items within inner arrays" do
      expect {
        described_class.validate_output_arrays!([["not an item"]], source: "test")
      }.to raise_error(DiscourseWorkflows::ItemContract::Error)
    end
  end
end
