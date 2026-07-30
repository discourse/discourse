# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::If::V1 do
  describe "#execute" do
    context "with combinators" do
      it "and: all conditions must pass" do
        config = {
          "conditions" => [
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
          "combinator" => "and",
          "options" => {
          },
        }

        items = [{ "json" => { "status" => "closed", "enabled" => true } }]
        result = execute_node_output(configuration: config, input_items: items)
        expect(result[0]).to eq(items)

        items = [{ "json" => { "status" => "closed", "enabled" => false } }]
        result = execute_node_output(configuration: config, input_items: items)
        expect(result[1]).to eq(items)
      end

      it "or: any condition passing is enough" do
        config = {
          "conditions" => [
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
          "combinator" => "or",
          "options" => {
          },
        }

        items = [{ "json" => { "status" => "archived" } }]
        result = execute_node_output(configuration: config, input_items: items)
        expect(result[0]).to eq(items)

        items = [{ "json" => { "status" => "open" } }]
        result = execute_node_output(configuration: config, input_items: items)
        expect(result[1]).to eq(items)
      end
    end

    context "with per-item routing" do
      it "routes items to different outputs based on condition" do
        config = {
          "conditions" => [
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
          "combinator" => "and",
          "options" => {
          },
        }

        items = [
          { "json" => { "status" => "closed", "id" => 1 } },
          { "json" => { "status" => "open", "id" => 2 } },
        ]
        result = execute_node_output(configuration: config, input_items: items)
        expect(result[0].length).to eq(1)
        expect(result[0].first["json"]["id"]).to eq(1)
        expect(result[1].length).to eq(1)
        expect(result[1].first["json"]["id"]).to eq(2)
      end
    end

    context "with missing context values" do
      it "treats missing fields as nil" do
        config = {
          "conditions" => [
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
          "combinator" => "and",
          "options" => {
          },
        }

        items = [{ "json" => { "status" => "closed" } }]
        result = execute_node_output(configuration: config, input_items: items)
        expect(result[1]).to eq(items)
      end
    end
  end
end
