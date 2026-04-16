# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::MarkdownTable::V1 do
  def execute(input_items, configuration = {})
    config = { "columns" => [] }.merge(configuration)
    instance = described_class.new(configuration: config)
    resolver_context = { "$json" => input_items.first&.dig("json") || {} }
    resolver = DiscourseWorkflows::ExpressionResolver.new(resolver_context)
    exec_ctx =
      DiscourseWorkflows::Executor::NodeExecutionContext.new(
        input_items: input_items,
        configuration: config,
        property_schema: described_class.property_schema,
        resolver: resolver,
        resolver_context: resolver_context,
      )
    result = instance.execute(exec_ctx)
    result[0].first&.dig("json", "markdown")
  end

  describe "metadata" do
    it "has the expected identifier and presentation" do
      expect(described_class.identifier).to eq("action:markdown_table")
      expect(described_class.icon).to eq("table-cells")
      expect(described_class.color).to eq("green")
      expect(described_class.group).to eq("data")
    end

    it "declares a columns collection with header and value fields" do
      schema = described_class.property_schema

      expect(schema[:columns]).to include(type: :collection, required: false)
      expect(schema.dig(:columns, :item_schema, :header)).to include(
        type: :string,
        required: true,
        ui: {
          expression: false,
        },
      )
      expect(schema.dig(:columns, :item_schema, :value)).to include(
        type: :string,
        required: true,
      )
    end
  end

  describe "#execute" do
    it "renders a table with a header row, separator, and one data row per input item" do
      items = [
        { "json" => { "name" => "Alice", "age" => "30" } },
        { "json" => { "name" => "Bob", "age" => "25" } },
      ]
      config = {
        "columns" => [
          { "header" => "Name", "value" => "={{ $json.name }}" },
          { "header" => "Age", "value" => "={{ $json.age }}" },
        ],
      }

      markdown = execute(items, config)

      expect(markdown).to eq(<<~MD.strip)
        | Name | Age |
        | --- | --- |
        | Alice | 30 |
        | Bob | 25 |
      MD
    end
  end
end
