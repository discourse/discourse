# frozen_string_literal: true

RSpec.describe DiscourseAi::Utils::BestEffortJsonParser do
  before { enable_current_plugin }

  describe ".extract_key" do
    context "with string type schema" do
      let(:schema_type) { "string" }
      let(:schema_key) { :output }

      it "handles JSON wrapped in markdown fences" do
        input = <<~JSON
          ```json
          {"output": "Hello world"}
          ```
        JSON
        result = described_class.extract_key(input, schema_type, schema_key)
        expect(result).to eq("Hello world")
      end

      it "handles JSON with backticks but no language identifier" do
        input = <<~JSON
          ```
          {"output": "Test message"}
          ```
        JSON
        result = described_class.extract_key(input, schema_type, schema_key)
        expect(result).to eq("Test message")
      end

      it "extracts value from malformed JSON with single quotes" do
        input = "{'output': 'Single quoted value'}"
        result = described_class.extract_key(input, schema_type, schema_key)
        expect(result).to eq("Single quoted value")
      end

      it "extracts value from JSON with unquoted keys" do
        input = "{output: \"Unquoted key value\"}"
        result = described_class.extract_key(input, schema_type, schema_key)
        expect(result).to eq("Unquoted key value")
      end

      it "handles JSON with extra text before and after" do
        input = <<~TEXT
          Here is the result:
          {"output": "Extracted value"}
          That's all!
        TEXT
        result = described_class.extract_key(input, schema_type, schema_key)
        expect(result).to eq("Extracted value")
      end

      it "handles nested JSON structures" do
        input = <<~JSON
          {
            "data": {
              "nested": true
            },
            "output": "Found me!"
          }
        JSON
        result = described_class.extract_key(input, schema_type, schema_key)
        expect(result).to eq("Found me!")
      end

      it "handles strings with escaped quotes" do
        input = '{"output": "She said \"Hello\" to me"}'
        result = described_class.extract_key(input, schema_type, schema_key)
        expect(result).to eq("She said \"Hello\" to me")
      end

      it "accepts string keys as well as symbols" do
        input = '{"output": "String key test"}'
        result = described_class.extract_key(input, schema_type, "output")
        expect(result).to eq("String key test")
      end
    end

    context "with array type schema" do
      let(:schema_type) { "array" }
      let(:schema_key) { :output }

      it "handles array wrapped in markdown fences" do
        input = <<~JSON
          ```json
          {"output": ["item1", "item2", "item3"]}
          ```
        JSON
        result = described_class.extract_key(input, schema_type, schema_key)
        expect(result).to eq(%w[item1 item2 item3])
      end

      it "extracts array from malformed JSON" do
        input = "{output: ['value1', 'value2']}"
        result = described_class.extract_key(input, schema_type, schema_key)
        expect(result).to eq(%w[value1 value2])
      end

      it "handles empty arrays" do
        input = <<~JSON
          ```json
          {"output": []}
          ```
        JSON
        result = described_class.extract_key(input, schema_type, schema_key)
        expect(result).to eq([])
      end

      it "handles arrays with mixed quotes" do
        input = '{output: ["item1", \'item2\']}'
        result = described_class.extract_key(input, schema_type, schema_key)
        expect(result).to eq(%w[item1 item2])
      end

      it "accepts string keys" do
        input = '{"items": ["a", "b"]}'
        result = described_class.extract_key(input, "array", "items")
        expect(result).to eq(%w[a b])
      end
    end

    context "with object type schema" do
      let(:schema_type) { "object" }
      let(:schema_key) { :data }

      it "extracts object from markdown fenced JSON" do
        input = <<~JSON
          ```json
          {
            "data": {
              "name": "Test",
              "value": 123
            }
          }
          ```
        JSON
        result = described_class.extract_key(input, schema_type, schema_key)
        expect(result).to eq({ "name" => "Test", "value" => 123 })
      end

      it "handles malformed object JSON" do
        input = "{data: {name: 'Test', value: 123}}"
        result = described_class.extract_key(input, schema_type, schema_key)
        expect(result).to eq({ "name" => "Test", "value" => 123 })
      end

      it "handles nested objects" do
        input = <<~JSON
          {
            "data": {
              "user": {
                "name": "John",
                "age": 30
              },
              "active": true
            }
          }
        JSON
        result = described_class.extract_key(input, schema_type, schema_key)
        expect(result).to eq({ "user" => { "name" => "John", "age" => 30 }, "active" => true })
      end
    end

    context "when very broken JSON is entered" do
      it "returns empty string when no valid JSON can be extracted for string type" do
        input = "This is just plain text with no JSON"
        result = described_class.extract_key(input, "string", :output)
        expect(result).to eq("")
      end

      it "returns empty array when array extraction fails" do
        input = "No array here"
        result = described_class.extract_key(input, "array", :output)
        expect(result).to eq([])
      end

      it "returns empty hash when object extraction fails" do
        input = "No object here"
        result = described_class.extract_key(input, "object", :data)
        expect(result).to eq({})
      end

      it "returns input as-is when it's not a string" do
        expect(described_class.extract_key(123, "string", :output)).to eq(123)
        expect(described_class.extract_key(["existing"], "array", :output)).to eq(["existing"])
        expect(described_class.extract_key({ existing: true }, "object", :output)).to eq(
          { existing: true },
        )
      end
    end
  end
end
