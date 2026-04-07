# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Filter::V1 do
  def build_exec_ctx(items)
    resolver =
      DiscourseWorkflows::ExpressionResolver.new({ "$json" => items.first&.dig("json") || {} })
    DiscourseWorkflows::NodeExecutionContext.new(input_items: items, resolver: resolver)
  end

  describe ".identifier" do
    it "returns condition:filter" do
      expect(described_class.identifier).to eq("condition:filter")
    end
  end

  describe ".branching?" do
    it "returns true" do
      expect(described_class.branching?).to be(true)
    end
  end

  describe ".ports" do
    it "defines kept and rejected output labels" do
      expect(described_class.ports).to eq(
        [
          { key: "true", primary: true, label_key: "discourse_workflows.executions.statuses.kept" },
          {
            key: "false",
            primary: false,
            label_key: "discourse_workflows.executions.statuses.rejected",
          },
        ],
      )
    end
  end

  describe "#execute" do
    it "routes passing items to true" do
      filter =
        described_class.new(
          configuration: {
            "conditions" => [
              {
                "id" => "1",
                "leftValue" => "={{ $json.category_id }}",
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
      result = filter.execute(build_exec_ctx(items))
      expect(result[0]).to eq(items)
      expect(result[1]).to eq([])
    end

    it "routes failing items to false" do
      filter =
        described_class.new(
          configuration: {
            "conditions" => [
              {
                "id" => "1",
                "leftValue" => "={{ $json.category_id }}",
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
      result = filter.execute(build_exec_ctx(items))
      expect(result[0]).to eq([])
      expect(result[1]).to eq(items)
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
      result = filter.execute(build_exec_ctx(items))
      expect(result[0]).to eq(items)
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
      result = filter.execute(build_exec_ctx(items))
      expect(result[0]).to eq(items)
    end

    it "filters out null array values for empty checks" do
      filter =
        described_class.new(
          configuration: {
            "conditions" => [
              {
                "id" => "1",
                "leftValue" => "={{ $json.tags }}",
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
      result = filter.execute(build_exec_ctx(items))
      expect(result[0]).to eq([])
      expect(result[1]).to eq(items)
    end
  end
end
