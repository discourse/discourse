# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Actions::SplitOut::V1 do
  def execute(input_items, configuration = {})
    config = { "field" => "items" }.merge(configuration)
    instance = described_class.new(configuration: config)
    instance.execute({}, input_items: input_items, node_context: {})
  end

  describe "basic array splitting" do
    it "splits an array field into separate items" do
      input = [{ "json" => { "name" => "test", "items" => [{ "a" => 1 }, { "a" => 2 }] } }]
      result = execute(input)

      expect(result.length).to eq(2)
      expect(result[0]["json"]).to include("a" => 1)
      expect(result[1]["json"]).to include("a" => 2)
    end

    it "wraps non-object array elements in a value key" do
      input = [{ "json" => { "tags" => %w[foo bar baz] } }]
      result = execute(input, "field" => "tags")

      expect(result.length).to eq(3)
      expect(result[0]["json"]).to eq({ "value" => "foo" })
      expect(result[1]["json"]).to eq({ "value" => "bar" })
    end

    it "wraps non-array values in an array (type coercion)" do
      input = [{ "json" => { "items" => "single" } }]
      result = execute(input)

      expect(result.length).to eq(1)
      expect(result[0]["json"]).to eq({ "value" => "single" })
    end

    it "converts non-array objects using values" do
      input = [{ "json" => { "items" => { "x" => 1, "y" => 2 } } }]
      result = execute(input)

      expect(result.length).to eq(2)
    end

    it "passes item through unchanged when field is missing" do
      input = [{ "json" => { "name" => "test" } }]
      result = execute(input)

      expect(result.length).to eq(1)
      expect(result[0]["json"]["name"]).to eq("test")
    end

    it "handles multiple input items" do
      input = [{ "json" => { "items" => [1, 2] } }, { "json" => { "items" => [3] } }]
      result = execute(input)

      expect(result.length).to eq(3)
    end
  end

  describe "include modes" do
    it "includes all other fields" do
      input = [{ "json" => { "company" => "Acme", "items" => [{ "n" => 1 }] } }]
      result = execute(input, "include" => "all_other_fields")

      expect(result.length).to eq(1)
      expect(result[0]["json"]).to include("company" => "Acme", "n" => 1)
    end

    it "includes selected other fields" do
      input = [{ "json" => { "company" => "Acme", "country" => "US", "items" => [{ "n" => 1 }] } }]
      result =
        execute(input, "include" => "selected_other_fields", "fields_to_include" => "company")

      expect(result[0]["json"]["company"]).to eq("Acme")
      expect(result[0]["json"]).not_to have_key("country")
    end
  end

  describe "dot notation" do
    it "accesses nested fields" do
      input = [{ "json" => { "data" => { "items" => [1, 2] } } }]
      result = execute(input, "field" => "data.items")

      expect(result.length).to eq(2)
    end
  end

  describe "multiple fields" do
    it "splits multiple fields simultaneously" do
      input = [{ "json" => { "names" => %w[a b], "ages" => [1, 2] } }]
      result = execute(input, "field" => "names, ages")

      expect(result.length).to eq(2)
      expect(result[0]["json"]).to include("names" => "a", "ages" => 1)
    end
  end

  describe "destination field name" do
    it "renames the output field" do
      input = [{ "json" => { "items" => [{ "a" => 1 }] } }]
      result = execute(input, "destination_field_name" => "result")

      expect(result[0]["json"]).to have_key("result")
    end
  end
end
