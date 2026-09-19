# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::SplitOut::V1 do
  def execute(input_items, configuration = {}, &block)
    config = { "field" => "items" }.merge(configuration)
    execute_node_output(configuration: config, input_items: input_items, &block).first
  end

  describe "basic array splitting" do
    it "splits an array field into separate items" do
      input = [{ "json" => { "name" => "test", "items" => [{ "a" => 1 }, { "a" => 2 }] } }]
      result = execute(input)

      expect(result.length).to eq(2)
      expect(result[0]["json"]).to include("a" => 1)
      expect(result[1]["json"]).to include("a" => 2)
    end

    it "keeps the original field name for non-object array elements" do
      input = [{ "json" => { "tags" => %w[foo bar baz] } }]
      result = execute(input, "field" => "tags")

      expect(result.length).to eq(3)
      expect(result[0]["json"]).to eq({ "tags" => "foo" })
      expect(result[1]["json"]).to eq({ "tags" => "bar" })
    end

    it "wraps non-array values in an array (type coercion)" do
      input = [{ "json" => { "items" => "single" } }]
      result = execute(input)

      expect(result.length).to eq(1)
      expect(result[0]["json"]).to eq({ "items" => "single" })
    end

    it "converts non-array objects using values" do
      input = [{ "json" => { "items" => { "x" => 1, "y" => 2 } } }]
      result = execute(input)

      expect(result.length).to eq(2)
      expect(result.map { |item| item["json"] }).to eq([{ "items" => 1 }, { "items" => 2 }])
    end

    it "emits no items when field is missing" do
      input = [{ "json" => { "name" => "test" } }]
      hints = nil
      result = execute(input) { |ctx| hints = ctx.execution_hints }

      expect(result).to eq([])
      expect(hints).to eq(
        [
          {
            "message" => "The field 'items' wasn't found in any input item.",
            "location" => "outputPane",
          },
        ],
      )
    end

    it "emits no items when field is empty" do
      input = [{ "json" => { "items" => [] } }]
      hints = nil
      result = execute(input) { |ctx| hints = ctx.execution_hints }

      expect(result).to eq([])
      expect(hints).to eq([])
    end

    it "does not add a missing field hint when any input item has the field" do
      input = [{ "json" => { "name" => "test" } }, { "json" => { "items" => [1] } }]
      hints = nil
      result = execute(input) { |ctx| hints = ctx.execution_hints }

      expect(result.map { |item| item["json"] }).to eq([{ "items" => 1 }])
      expect(hints).to eq([])
    end

    it "resolves split field and destination expressions for each input item" do
      input = [
        { "json" => { "field" => "items", "destination" => "item", "items" => [1] } },
        { "json" => { "field" => "values", "destination" => "value", "values" => [2] } },
      ]
      result =
        execute(
          input,
          "field" => "={{ $json.field }}",
          "destination_field_name" => "={{ $json.destination }}",
        )

      expect(result.map { |item| item["json"] }).to eq([{ "item" => 1 }, { "value" => 2 }])
    end

    it "handles multiple input items" do
      input = [{ "json" => { "items" => [1, 2] } }, { "json" => { "items" => [3] } }]
      result = execute(input)

      expect(result.length).to eq(3)
    end

    it "links split output items to their source input item" do
      input = [{ "json" => { "items" => [1, 2] } }, { "json" => { "items" => [3] } }]
      result = execute(input)

      expect(result.map { |item| item["pairedItem"] }).to eq(
        [{ "item" => 0 }, { "item" => 0 }, { "item" => 1 }],
      )
    end
  end

  describe "include modes" do
    it "includes all other fields" do
      input = [{ "json" => { "company" => "Acme", "items" => [{ "n" => 1 }] } }]
      result = execute(input, "include" => "all_other_fields")

      expect(result.length).to eq(1)
      expect(result[0]["json"]).to include("company" => "Acme", "items" => { "n" => 1 })
    end

    it "includes selected other fields" do
      input = [{ "json" => { "company" => "Acme", "country" => "US", "items" => [{ "n" => 1 }] } }]
      result =
        execute(input, "include" => "selected_other_fields", "fields_to_include" => "company")

      expect(result[0]["json"]["company"]).to eq("Acme")
      expect(result[0]["json"]["items"]).to eq("n" => 1)
      expect(result[0]["json"]).not_to have_key("country")
    end

    it "resolves include mode expressions" do
      input = [{ "json" => { "company" => "Acme", "items" => [1] } }]
      result = execute(input, "include" => "={{ 'all_other_fields' }}")

      expect(result.first["json"]).to eq("company" => "Acme", "items" => 1)
    end

    it "raises DiscourseWorkflows::NodeError when selected fields are blank" do
      input = [{ "json" => { "items" => [{ "n" => 1 }] } }]

      expect { execute(input, "include" => "selected_other_fields") }.to raise_error(
        DiscourseWorkflows::NodeError,
        /No fields specified/,
      )
    end

    it "does not validate selected fields when there are no split items" do
      input = [{ "json" => { "items" => [] } }]

      expect(execute(input, "include" => "selected_other_fields")).to eq([])
    end
  end

  describe "dot notation" do
    it "accesses nested fields" do
      input = [{ "json" => { "data" => { "items" => [1, 2] } } }]
      result = execute(input, "field" => "data.items")

      expect(result.length).to eq(2)
      expect(result.first["json"]).to eq("data.items" => 1)
    end

    it "strips a leading $json prefix from field names" do
      input = [{ "json" => { "items" => [1] } }]
      result = execute(input, "field" => "$json.items")

      expect(result.first["json"]).to eq("items" => 1)
    end
  end

  describe "multiple fields" do
    it "splits multiple fields simultaneously" do
      input = [{ "json" => { "names" => %w[a b], "ages" => [1, 2] } }]
      result = execute(input, "field" => "names, ages")

      expect(result.length).to eq(2)
      expect(result[0]["json"]).to include("names" => "a", "ages" => 1)
    end

    it "omits fields that have no element at the split index" do
      input = [{ "json" => { "names" => %w[a b], "ages" => [1] } }]
      result = execute(input, "field" => "names, ages")

      expect(result.map { |item| item["json"] }).to eq(
        [{ "names" => "a", "ages" => 1 }, { "names" => "b" }],
      )
    end
  end

  describe "destination field name" do
    it "renames the output field" do
      input = [{ "json" => { "items" => [{ "a" => 1 }] } }]
      result = execute(input, "destination_field_name" => "result")

      expect(result[0]["json"]).to have_key("result")
    end
  end

  describe "item limit" do
    it "raises DiscourseWorkflows::NodeError when array exceeds MAX_SPLIT_ITEMS" do
      oversized_array = (1..(described_class::MAX_SPLIT_ITEMS + 1)).map { |n| { "n" => n } }
      input = [{ "json" => { "items" => oversized_array } }]

      expect { execute(input) }.to raise_error(
        DiscourseWorkflows::NodeError,
        /Cannot split into more than/,
      )
    end
  end
end
