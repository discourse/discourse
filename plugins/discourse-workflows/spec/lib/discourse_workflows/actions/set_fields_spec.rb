# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Actions::SetFields do
  before { SiteSetting.discourse_workflows_enabled = true }

  describe ".identifier" do
    it "returns the correct identifier" do
      expect(described_class.identifier).to eq("action:set_fields")
    end
  end

  describe "#execute_single" do
    let(:context) { { "trigger" => { "topic_id" => "42" } } }
    let(:item) { { "json" => { "topic_id" => "42", "username" => "alice" } } }

    it "returns typed fields from fixed values" do
      action = described_class.new(configuration: {})
      config = {
        "include_input" => false,
        "fields" => [
          { "key" => "priority", "value" => "high", "type" => "string" },
          { "key" => "days", "value" => "7", "type" => "integer" },
          { "key" => "notify", "value" => "true", "type" => "boolean" },
        ],
      }

      result = action.execute_single(context, item: item, config: config)

      expect(result).to eq({ "priority" => "high", "days" => 7, "notify" => true })
    end

    it "merges with item json when include_input is true" do
      action = described_class.new(configuration: {})
      config = {
        "include_input" => true,
        "fields" => [{ "key" => "priority", "value" => "high", "type" => "string" }],
      }

      result = action.execute_single(context, item: item, config: config)

      expect(result).to eq({ "topic_id" => "42", "username" => "alice", "priority" => "high" })
    end

    it "set fields win on merge conflict" do
      action = described_class.new(configuration: {})
      config = {
        "include_input" => true,
        "fields" => [{ "key" => "username", "value" => "bob", "type" => "string" }],
      }

      result = action.execute_single(context, item: item, config: config)

      expect(result["username"]).to eq("bob")
    end

    it "defaults include_input to true when not specified" do
      action = described_class.new(configuration: {})
      config = { "fields" => [{ "key" => "status", "value" => "open", "type" => "string" }] }

      result = action.execute_single(context, item: item, config: config)

      expect(result).to include("topic_id" => "42", "status" => "open")
    end

    it "casts boolean falsy values correctly" do
      action = described_class.new(configuration: {})
      config = {
        "include_input" => false,
        "fields" => [
          { "key" => "a", "value" => "false", "type" => "boolean" },
          { "key" => "b", "value" => "0", "type" => "boolean" },
          { "key" => "c", "value" => "no", "type" => "boolean" },
          { "key" => "d", "value" => "1", "type" => "boolean" },
        ],
      }

      result = action.execute_single(context, item: item, config: config)

      expect(result).to eq({ "a" => false, "b" => false, "c" => false, "d" => true })
    end

    it "raises on non-numeric integer cast" do
      action = described_class.new(configuration: {})
      config = {
        "include_input" => false,
        "fields" => [{ "key" => "count", "value" => "abc", "type" => "integer" }],
      }

      expect { action.execute_single(context, item: item, config: config) }.to raise_error(
        ArgumentError,
      )
    end

    it "returns empty hash when fields are empty and include_input is false" do
      action = described_class.new(configuration: {})
      config = { "include_input" => false, "fields" => [] }

      result = action.execute_single(context, item: item, config: config)

      expect(result).to eq({})
    end

    it "returns item json when fields are empty and include_input is true" do
      action = described_class.new(configuration: {})
      config = { "include_input" => true, "fields" => [] }

      result = action.execute_single(context, item: item, config: config)

      expect(result).to eq(item["json"])
    end

    it "skips fields with blank keys" do
      action = described_class.new(configuration: {})
      config = {
        "include_input" => false,
        "fields" => [
          { "key" => "", "value" => "ignored", "type" => "string" },
          { "key" => "kept", "value" => "yes", "type" => "string" },
        ],
      }

      result = action.execute_single(context, item: item, config: config)

      expect(result).to eq({ "kept" => "yes" })
    end

    context "with json mode" do
      it "parses valid JSON and returns typed values" do
        action = described_class.new(configuration: {})
        config = {
          "mode" => "json",
          "include_input" => false,
          "json" => '{"status": "active", "count": 42, "enabled": true}',
        }

        result = action.execute_single(context, item: item, config: config)

        expect(result).to eq({ "status" => "active", "count" => 42, "enabled" => true })
      end

      it "merges with item json when include_input is true" do
        action = described_class.new(configuration: {})
        config = { "mode" => "json", "include_input" => true, "json" => '{"priority": "high"}' }

        result = action.execute_single(context, item: item, config: config)

        expect(result).to eq({ "topic_id" => "42", "username" => "alice", "priority" => "high" })
      end

      it "returns only parsed JSON when include_input is false" do
        action = described_class.new(configuration: {})
        config = { "mode" => "json", "include_input" => false, "json" => '{"only": "this"}' }

        result = action.execute_single(context, item: item, config: config)

        expect(result).to eq({ "only" => "this" })
      end

      it "raises on invalid JSON" do
        action = described_class.new(configuration: {})
        config = { "mode" => "json", "include_input" => false, "json" => "not valid json{" }

        expect { action.execute_single(context, item: item, config: config) }.to raise_error(
          JSON::ParserError,
        )
      end

      it "raises when JSON is not an object" do
        action = described_class.new(configuration: {})
        config = { "mode" => "json", "include_input" => false, "json" => '["an", "array"]' }

        expect { action.execute_single(context, item: item, config: config) }.to raise_error(
          ArgumentError,
          "JSON must be an object",
        )
      end

      it "raises when JSON string is blank" do
        action = described_class.new(configuration: {})
        config = { "mode" => "json", "include_input" => false, "json" => "" }

        expect { action.execute_single(context, item: item, config: config) }.to raise_error(
          ArgumentError,
          "JSON string is blank",
        )
      end
    end

    it "defaults to manual mode when no mode key is present" do
      action = described_class.new(configuration: {})
      config = {
        "include_input" => false,
        "fields" => [{ "key" => "status", "value" => "open", "type" => "string" }],
      }

      result = action.execute_single(context, item: item, config: config)

      expect(result).to eq({ "status" => "open" })
    end
  end
end
