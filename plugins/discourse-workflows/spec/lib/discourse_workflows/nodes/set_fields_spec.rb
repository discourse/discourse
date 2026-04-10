# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::SetFields::V1 do
  describe ".identifier" do
    it "returns the correct identifier" do
      expect(described_class.identifier).to eq("action:set_fields")
    end
  end

  def execute_node(configuration:, item:)
    action = described_class.new(configuration: configuration)
    input_items = [item]
    resolver = DiscourseWorkflows::ExpressionResolver.new({ "$json" => item.fetch("json") { {} } })
    exec_ctx =
      DiscourseWorkflows::NodeExecutionContext.new(
        input_items: input_items,
        resolver: resolver,
        configuration: configuration,
        configuration_schema: described_class.configuration_schema,
      )
    items = action.execute(exec_ctx)[0]
    items.first["json"]
  end

  describe "#execute" do
    let(:item) { { "json" => { "topic_id" => "42", "username" => "alice" } } }

    it "returns typed fields from fixed values" do
      config = {
        "include_input" => false,
        "fields" => [
          { "key" => "priority", "value" => "high", "type" => "string" },
          { "key" => "days", "value" => "7", "type" => "integer" },
          { "key" => "notify", "value" => "true", "type" => "boolean" },
        ],
      }

      result = execute_node(configuration: config, item: item)

      expect(result).to eq({ "priority" => "high", "days" => 7, "notify" => true })
    end

    it "merges with item json when include_input is true" do
      config = {
        "include_input" => true,
        "fields" => [{ "key" => "priority", "value" => "high", "type" => "string" }],
      }

      result = execute_node(configuration: config, item: item)

      expect(result).to eq({ "topic_id" => "42", "username" => "alice", "priority" => "high" })
    end

    it "set fields win on merge conflict" do
      config = {
        "include_input" => true,
        "fields" => [{ "key" => "username", "value" => "bob", "type" => "string" }],
      }

      result = execute_node(configuration: config, item: item)

      expect(result["username"]).to eq("bob")
    end

    it "defaults include_input to true when not specified" do
      config = { "fields" => [{ "key" => "status", "value" => "open", "type" => "string" }] }

      result = execute_node(configuration: config, item: item)

      expect(result).to include("topic_id" => "42", "status" => "open")
    end

    it "casts boolean falsy values correctly" do
      config = {
        "include_input" => false,
        "fields" => [
          { "key" => "a", "value" => "false", "type" => "boolean" },
          { "key" => "b", "value" => "0", "type" => "boolean" },
          { "key" => "c", "value" => "no", "type" => "boolean" },
          { "key" => "d", "value" => "1", "type" => "boolean" },
        ],
      }

      result = execute_node(configuration: config, item: item)

      expect(result).to eq({ "a" => false, "b" => false, "c" => false, "d" => true })
    end

    it "raises on non-numeric integer cast" do
      config = {
        "include_input" => false,
        "fields" => [{ "key" => "count", "value" => "abc", "type" => "integer" }],
      }

      expect { execute_node(configuration: config, item: item) }.to raise_error(ArgumentError)
    end

    it "returns empty hash when fields are empty and include_input is false" do
      config = { "include_input" => false, "fields" => [] }

      result = execute_node(configuration: config, item: item)

      expect(result).to eq({})
    end

    it "returns item json when fields are empty and include_input is true" do
      config = { "include_input" => true, "fields" => [] }

      result = execute_node(configuration: config, item: item)

      expect(result).to eq(item["json"])
    end

    it "skips fields with blank keys" do
      config = {
        "include_input" => false,
        "fields" => [
          { "key" => "", "value" => "ignored", "type" => "string" },
          { "key" => "kept", "value" => "yes", "type" => "string" },
        ],
      }

      result = execute_node(configuration: config, item: item)

      expect(result).to eq({ "kept" => "yes" })
    end

    context "with json mode" do
      it "parses valid JSON and returns typed values" do
        config = {
          "mode" => "json",
          "include_input" => false,
          "json" => '{"status": "active", "count": 42, "enabled": true}',
        }

        result = execute_node(configuration: config, item: item)

        expect(result).to eq({ "status" => "active", "count" => 42, "enabled" => true })
      end

      it "merges with item json when include_input is true" do
        config = { "mode" => "json", "include_input" => true, "json" => '{"priority": "high"}' }

        result = execute_node(configuration: config, item: item)

        expect(result).to eq({ "topic_id" => "42", "username" => "alice", "priority" => "high" })
      end

      it "returns only parsed JSON when include_input is false" do
        config = { "mode" => "json", "include_input" => false, "json" => '{"only": "this"}' }

        result = execute_node(configuration: config, item: item)

        expect(result).to eq({ "only" => "this" })
      end

      it "raises on invalid JSON" do
        config = { "mode" => "json", "include_input" => false, "json" => "not valid json{" }

        expect { execute_node(configuration: config, item: item) }.to raise_error(JSON::ParserError)
      end

      it "raises when JSON is not an object" do
        config = { "mode" => "json", "include_input" => false, "json" => '["an", "array"]' }

        expect { execute_node(configuration: config, item: item) }.to raise_error(
          ArgumentError,
          "JSON must be an object",
        )
      end

      it "raises when JSON string is blank" do
        config = { "mode" => "json", "include_input" => false, "json" => "" }

        expect { execute_node(configuration: config, item: item) }.to raise_error(
          ArgumentError,
          "JSON string is blank",
        )
      end
    end

    it "defaults to manual mode when no mode key is present" do
      config = {
        "include_input" => false,
        "fields" => [{ "key" => "status", "value" => "open", "type" => "string" }],
      }

      result = execute_node(configuration: config, item: item)

      expect(result).to eq({ "status" => "open" })
    end
  end
end
