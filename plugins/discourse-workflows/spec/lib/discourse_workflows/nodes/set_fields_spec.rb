# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::SetFields::V1 do
  it "does not expose optional options" do
    expect(described_class.property_schema).not_to have_key(:options)
  end

  describe "#execute" do
    let(:item) { { "json" => { "topic_id" => "42", "username" => "alice" } } }

    def assignments(*rows)
      { "assignments" => { "assignments" => rows } }
    end

    def assignment(name, value, type = "string")
      { "name" => name, "value" => value, "type" => type }
    end

    it "returns typed fields from fixed values" do
      config = { "include_other_fields" => false }.merge(
        assignments(
          assignment("priority", "high"),
          assignment("days", "7", "integer"),
          assignment("notify", "true", "boolean"),
        ),
      )

      result = execute_node(configuration: config, item: item)

      expect(result).to eq({ "priority" => "high", "days" => 7, "notify" => true })
    end

    it "merges with item json when include_input is true" do
      config = { "include_other_fields" => true }.merge(assignments(assignment("priority", "high")))

      result = execute_node(configuration: config, item: item)

      expect(result).to eq({ "topic_id" => "42", "username" => "alice", "priority" => "high" })
    end

    it "set fields win on merge conflict" do
      config = { "include_other_fields" => true }.merge(assignments(assignment("username", "bob")))

      result = execute_node(configuration: config, item: item)

      expect(result["username"]).to eq("bob")
    end

    it "defaults include_other_fields to true when not specified" do
      config = assignments(assignment("status", "open"))

      result = execute_node(configuration: config, item: item)

      expect(result).to include("topic_id" => "42", "status" => "open")
    end

    it "casts boolean falsy values correctly" do
      config = { "include_other_fields" => false }.merge(
        assignments(
          assignment("a", "false", "boolean"),
          assignment("b", "0", "boolean"),
          assignment("c", "no", "boolean"),
          assignment("d", "1", "boolean"),
        ),
      )

      result = execute_node(configuration: config, item: item)

      expect(result).to eq({ "a" => false, "b" => false, "c" => false, "d" => true })
    end

    it "casts float values" do
      config = { "include_other_fields" => false }.merge(
        assignments(assignment("score", "3.14", "float"), assignment("whole", "7", "float")),
      )

      result = execute_node(configuration: config, item: item)

      expect(result).to eq({ "score" => 3.14, "whole" => 7.0 })
    end

    it "raises on non-numeric float cast" do
      config = { "include_other_fields" => false }.merge(
        assignments(assignment("score", "abc", "float")),
      )

      expect { execute_node(configuration: config, item: item) }.to raise_error(
        DiscourseWorkflows::NodeError,
      )
    end

    it "raises on non-numeric integer cast" do
      config = { "include_other_fields" => false }.merge(
        assignments(assignment("count", "abc", "integer")),
      )

      expect { execute_node(configuration: config, item: item) }.to raise_error(
        DiscourseWorkflows::NodeError,
      )
    end

    it "returns empty hash when fields are empty and include_input is false" do
      config = { "include_other_fields" => false }.merge(assignments)

      result = execute_node(configuration: config, item: item)

      expect(result).to eq({})
    end

    it "returns item json when fields are empty and include_input is true" do
      config = { "include_other_fields" => true }.merge(assignments)

      result = execute_node(configuration: config, item: item)

      expect(result).to eq(item["json"])
    end

    it "skips fields with blank keys" do
      config = { "include_other_fields" => false }.merge(
        assignments(assignment("", "ignored"), assignment("kept", "yes")),
      )

      result = execute_node(configuration: config, item: item)

      expect(result).to eq({ "kept" => "yes" })
    end

    it "sets nested fields with dot notation" do
      config = { "include_other_fields" => false }.merge(
        assignments(assignment("profile.name", "Alice")),
      )

      result = execute_node(configuration: config, item: item)

      expect(result).to eq({ "profile" => { "name" => "Alice" } })
    end

    it "includes only selected input fields" do
      nested_item = { "json" => item["json"].merge("profile" => { "name" => "Alice" }) }
      config = { "include" => "selected", "include_fields" => "topic_id, profile.name" }.merge(
        assignments,
      )

      result = execute_node(configuration: config, item: nested_item)

      expect(result).to eq({ "topic_id" => "42", "name" => "Alice" })
    end

    it "excludes selected input fields" do
      config = { "include" => "except", "exclude_fields" => "username" }.merge(assignments)

      result = execute_node(configuration: config, item: item)

      expect(result).to eq({ "topic_id" => "42" })
    end

    context "with raw JSON mode" do
      it "parses valid JSON and returns typed values" do
        config = {
          "mode" => "raw",
          "include_other_fields" => false,
          "json_output" => '{"status": "active", "count": 42, "enabled": true}',
        }

        result = execute_node(configuration: config, item: item)

        expect(result).to eq({ "status" => "active", "count" => 42, "enabled" => true })
      end

      it "merges with item json when include_input is true" do
        config = {
          "mode" => "raw",
          "include_other_fields" => true,
          "json_output" => '{"priority": "high"}',
        }

        result = execute_node(configuration: config, item: item)

        expect(result).to eq({ "topic_id" => "42", "username" => "alice", "priority" => "high" })
      end

      it "returns only parsed JSON when include_input is false" do
        config = {
          "mode" => "raw",
          "include_other_fields" => false,
          "json_output" => '{"only": "this"}',
        }

        result = execute_node(configuration: config, item: item)

        expect(result).to eq({ "only" => "this" })
      end

      it "raises on invalid JSON" do
        config = {
          "mode" => "raw",
          "include_other_fields" => false,
          "json_output" => "not valid json{",
        }

        expect { execute_node(configuration: config, item: item) }.to raise_error(
          DiscourseWorkflows::NodeError,
        )
      end

      it "raises when JSON is not an object" do
        config = {
          "mode" => "raw",
          "include_other_fields" => false,
          "json_output" => '["an", "array"]',
        }

        expect { execute_node(configuration: config, item: item) }.to raise_error(
          DiscourseWorkflows::NodeError,
          "JSON must be an object.",
        )
      end

      it "raises when JSON string is blank" do
        config = { "mode" => "raw", "include_other_fields" => false, "json_output" => "" }

        expect { execute_node(configuration: config, item: item) }.to raise_error(
          DiscourseWorkflows::NodeError,
          "JSON string is blank.",
        )
      end
    end

    it "defaults to manual mode when no mode key is present" do
      config = { "include_other_fields" => false }.merge(assignments(assignment("status", "open")))

      result = execute_node(configuration: config, item: item)

      expect(result).to eq({ "status" => "open" })
    end
  end
end
