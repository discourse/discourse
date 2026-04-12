# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Filter::V1 do
  def build_exec_ctx(items, configuration: {})
    resolver =
      DiscourseWorkflows::ExpressionResolver.new({ "$json" => items.first&.dig("json") || {} })
    DiscourseWorkflows::NodeExecutionContext.new(
      input_items: items,
      configuration: configuration,
      property_schema: described_class.property_schema,
      resolver: resolver,
    )
  end

  describe "#execute" do
    let(:category_id_equals_5_config) do
      {
        "conditions" => [
          {
            "id" => "1",
            "leftValue" => "={{ $json.category_id }}",
            "rightValue" => "5",
            "operator" => {
              "type" => "integer",
              "operation" => "equals",
            },
          },
        ],
        "combinator" => "and",
      }
    end

    it "routes passing items to true" do
      filter = described_class.new(configuration: category_id_equals_5_config)

      items = [{ "json" => { "category_id" => 5 } }]
      result = filter.execute(build_exec_ctx(items, configuration: category_id_equals_5_config))
      expect(result[0]).to eq(items)
      expect(result[1]).to eq([])
    end

    it "routes failing items to false" do
      filter = described_class.new(configuration: category_id_equals_5_config)

      items = [{ "json" => { "category_id" => 10 } }]
      result = filter.execute(build_exec_ctx(items, configuration: category_id_equals_5_config))
      expect(result[0]).to eq([])
      expect(result[1]).to eq(items)
    end

    it "uses already-resolved string literals as values" do
      config = {
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
      }
      filter = described_class.new(configuration: config)

      items = [{ "json" => { "category_id" => 5 } }]
      result = filter.execute(build_exec_ctx(items, configuration: config))
      expect(result[0]).to eq(items)
    end

    it "works with expression-resolved left values" do
      config = {
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
      }
      filter = described_class.new(configuration: config)

      items = [{ "json" => {} }]
      result = filter.execute(build_exec_ctx(items, configuration: config))
      expect(result[0]).to eq(items)
    end

    it "filters out null array values for empty checks" do
      config = {
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
      }
      filter = described_class.new(configuration: config)

      items = [{ "json" => { "tags" => nil } }]
      result = filter.execute(build_exec_ctx(items, configuration: config))
      expect(result[0]).to eq([])
      expect(result[1]).to eq(items)
    end
  end
end
