# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::If::V1 do
  def build_config(conditions:, combinator: "and", options: {})
    { "conditions" => conditions, "combinator" => combinator, "options" => options }
  end

  def wrap_items(*jsons)
    jsons.map { |json| { "json" => json } }
  end

  describe "#execute" do
    context "with combinators" do
      it "and: all conditions must pass" do
        config =
          build_config(
            conditions: [
              {
                "id" => "1",
                "leftValue" => "={{ $json.status }}",
                "rightValue" => "closed",
                "operator" => {
                  "type" => "string",
                  "operation" => "equals",
                },
              },
              {
                "id" => "2",
                "leftValue" => "={{ $json.enabled }}",
                "operator" => {
                  "type" => "boolean",
                  "operation" => "true",
                  "singleValue" => true,
                },
              },
            ],
            combinator: "and",
          )

        items = wrap_items({ "status" => "closed", "enabled" => true })
        result = execute_node_output(configuration: config, input_items: items)
        expect(result[0]).to eq(items)

        items = wrap_items({ "status" => "closed", "enabled" => false })
        result = execute_node_output(configuration: config, input_items: items)
        expect(result[1]).to eq(items)
      end

      it "or: any condition passing is enough" do
        config =
          build_config(
            conditions: [
              {
                "id" => "1",
                "leftValue" => "={{ $json.status }}",
                "rightValue" => "closed",
                "operator" => {
                  "type" => "string",
                  "operation" => "equals",
                },
              },
              {
                "id" => "2",
                "leftValue" => "={{ $json.status }}",
                "rightValue" => "archived",
                "operator" => {
                  "type" => "string",
                  "operation" => "equals",
                },
              },
            ],
            combinator: "or",
          )

        items = wrap_items({ "status" => "archived" })
        result = execute_node_output(configuration: config, input_items: items)
        expect(result[0]).to eq(items)

        items = wrap_items({ "status" => "open" })
        result = execute_node_output(configuration: config, input_items: items)
        expect(result[1]).to eq(items)
      end
    end

    context "with per-item routing" do
      it "routes items to different outputs based on condition" do
        config =
          build_config(
            conditions: [
              {
                "id" => "1",
                "leftValue" => "={{ $json.status }}",
                "rightValue" => "closed",
                "operator" => {
                  "type" => "string",
                  "operation" => "equals",
                },
              },
            ],
          )

        items = wrap_items({ "status" => "closed", "id" => 1 }, { "status" => "open", "id" => 2 })
        result = execute_node_output(configuration: config, input_items: items)
        expect(result[0].length).to eq(1)
        expect(result[0].first["json"]["id"]).to eq(1)
        expect(result[1].length).to eq(1)
        expect(result[1].first["json"]["id"]).to eq(2)
      end
    end

    context "with missing context values" do
      it "treats missing fields as nil" do
        config =
          build_config(
            conditions: [
              {
                "id" => "1",
                "leftValue" => "={{ $json.nonexistent }}",
                "rightValue" => "something",
                "operator" => {
                  "type" => "string",
                  "operation" => "equals",
                },
              },
            ],
          )

        items = wrap_items({ "status" => "closed" })
        result = execute_node_output(configuration: config, input_items: items)
        expect(result[1]).to eq(items)
      end
    end
  end
end
