# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Filter::V1 do
  describe "#execute" do
    let(:category_id_equals_5_config) do
      {
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
      }
    end

    it "routes passing items to true" do
      items = [{ "json" => { "category_id" => 5 } }]
      result = execute_node_output(configuration: category_id_equals_5_config, input_items: items)
      expect(result[0]).to eq(items)
      expect(result[1]).to eq([])
    end

    it "routes failing items to false" do
      items = [{ "json" => { "category_id" => 10 } }]
      result = execute_node_output(configuration: category_id_equals_5_config, input_items: items)
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
      items = [{ "json" => { "category_id" => 5 } }]
      result = execute_node_output(configuration: config, input_items: items)
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
      items = [{ "json" => {} }]
      result = execute_node_output(configuration: config, input_items: items)
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
      items = [{ "json" => { "tags" => nil } }]
      result = execute_node_output(configuration: config, input_items: items)
      expect(result[0]).to eq([])
      expect(result[1]).to eq(items)
    end
  end
end
