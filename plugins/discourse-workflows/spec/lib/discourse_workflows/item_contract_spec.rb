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

    it "accepts compatible pairedItem metadata" do
      items = [
        {
          "json" => {
            "a" => 1,
          },
          "pairedItem" => [{ "input" => 0, "item" => 0 }, { "input" => 1, "item" => 2 }],
        },
      ]

      expect { described_class.validate_items!(items, source: "test") }.not_to raise_error
    end

    it "accepts shorthand pairedItem metadata" do
      items = [{ "json" => {}, "pairedItem" => 0 }]

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

    it "rejects unsupported top-level item keys" do
      expect {
        described_class.validate_items!([{ "json" => {}, "binary" => {} }], source: "test")
      }.to raise_error(DiscourseWorkflows::ItemContract::Error, /Invalid item keys/)
    end

    it "rejects items with non-object json data" do
      expect {
        described_class.validate_items!([{ "json" => "not an object" }], source: "test")
      }.to raise_error(DiscourseWorkflows::ItemContract::Error)
    end

    it "rejects items that are not hashes" do
      expect { described_class.validate_items!(["string"], source: "test") }.to raise_error(
        DiscourseWorkflows::ItemContract::Error,
      )
    end

    it "rejects invalid pairedItem metadata" do
      items = [{ "json" => {}, "pairedItem" => { "item" => "0" } }]

      expect { described_class.validate_items!(items, source: "test") }.to raise_error(
        DiscourseWorkflows::ItemContract::Error,
        /Invalid pairedItem/,
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

    it "rejects more outputs than the node declares" do
      expect {
        described_class.validate_output_arrays!(
          [[{ "json" => { "a" => 1 } }], [{ "json" => { "b" => 2 } }]],
          source: "test",
          ports: [{ key: "main" }],
        )
      }.to raise_error(DiscourseWorkflows::ItemContract::Error, /returned 2 outputs/)
    end
  end
end
