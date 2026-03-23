# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Conditions::Filter::V1 do
  describe ".identifier" do
    it "returns condition:filter" do
      expect(described_class.identifier).to eq("condition:filter")
    end
  end

  describe ".branching?" do
    it "returns true" do
      expect(described_class.branching?).to eq(true)
    end
  end

  describe "#evaluate" do
    it "routes passing items to true" do
      filter =
        described_class.new(
          configuration: {
            "conditions" => [
              {
                "id" => "1",
                "leftValue" => "category_id",
                "rightValue" => "5",
                "operator" => {
                  "type" => "number",
                  "operation" => "equals",
                },
              },
            ],
            "combinator" => "and",
          },
        )

      items = [{ "json" => { "category_id" => 5 } }]
      result = filter.evaluate(input_items: items)
      expect(result["true"]).to eq(items)
      expect(result["false"]).to eq([])
    end

    it "routes failing items to false" do
      filter =
        described_class.new(
          configuration: {
            "conditions" => [
              {
                "id" => "1",
                "leftValue" => "category_id",
                "rightValue" => "5",
                "operator" => {
                  "type" => "number",
                  "operation" => "equals",
                },
              },
            ],
            "combinator" => "and",
          },
        )

      items = [{ "json" => { "category_id" => 10 } }]
      result = filter.evaluate(input_items: items)
      expect(result["true"]).to eq([])
      expect(result["false"]).to eq(items)
    end

    it "uses already-resolved string literals as values" do
      filter =
        described_class.new(
          configuration: {
            "conditions" => [
              {
                "id" => "1",
                "leftValue" => "2",
                "rightValue" => "2",
                "operator" => {
                  "type" => "string",
                  "operation" => "equals",
                },
              },
            ],
            "combinator" => "and",
          },
        )

      items = [{ "json" => { "category_id" => 5 } }]
      result = filter.evaluate(input_items: items)
      expect(result["true"]).to eq(items)
    end

    it "works with expression-resolved left values" do
      filter =
        described_class.new(
          configuration: {
            "conditions" => [
              {
                "id" => "1",
                "leftValue" => %w[bug help],
                "rightValue" => "bug",
                "operator" => {
                  "type" => "array",
                  "operation" => "contains",
                },
              },
            ],
            "combinator" => "and",
          },
        )

      items = [{ "json" => {} }]
      result = filter.evaluate(input_items: items)
      expect(result["true"]).to eq(items)
    end

    it "filters out null array values for empty checks" do
      filter =
        described_class.new(
          configuration: {
            "conditions" => [
              {
                "id" => "1",
                "leftValue" => "tags",
                "operator" => {
                  "type" => "array",
                  "operation" => "empty",
                  "singleValue" => true,
                },
              },
            ],
            "combinator" => "and",
          },
        )

      items = [{ "json" => { "tags" => nil } }]
      result = filter.evaluate(input_items: items)
      expect(result["true"]).to eq([])
      expect(result["false"]).to eq(items)
    end
  end
end
