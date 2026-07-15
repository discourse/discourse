# frozen_string_literal: true

RSpec.describe DiscourseAi::WorkflowSchemaFields do
  before { enable_current_plugin }

  describe ".convert" do
    it "flattens a workflow output JSON Schema to compact AI paths" do
      schema = {
        type: "object",
        properties: {
          user: {
            type: "object",
            description: "Basic safe user attributes",
            properties: {
              username: {
                type: "string",
              },
              name: {
                type: %w[string null],
              },
              created_at: {
                type: "string",
                format: "date-time",
              },
              tags: {
                type: "array",
                items: {
                  type: "string",
                },
              },
              groups: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    id: {
                      type: "integer",
                    },
                    name: {
                      type: %w[string null],
                    },
                  },
                },
              },
            },
          },
          membership: {
            type: "object",
            description: "Group membership event metadata",
            properties: {
              action: {
                const: "added",
              },
              automatic: {
                type: %w[boolean null],
              },
              removed_at: {
                type: "null",
              },
            },
          },
        },
      }

      expect(described_class.convert(schema)).to eq(
        "user" => "Basic safe user attributes",
        "user.username" => "string",
        "user.name" => "string|null",
        "user.created_at" => "datetime",
        "user.tags" => "array<string>",
        "user.groups" => "array<object>",
        "user.groups[0].id" => "integer",
        "user.groups[0].name" => "string|null",
        "membership" => "Group membership event metadata",
        "membership.action" => '"added"',
        "membership.automatic" => "boolean|null",
        "membership.removed_at" => "null",
      )
    end

    it "does not interpret a flat field map as a schema" do
      expect(described_class.convert("result" => "string")).to eq({})
      expect(described_class.convert(nil)).to eq({})
    end

    it "preserves property segments that require bracket notation" do
      schema = {
        type: "object",
        properties: {
          "full-name" => {
            type: "string",
          },
          "a.b" => {
            type: "boolean",
          },
          :a => {
            type: "object",
            properties: {
              :b => {
                type: "integer",
              },
              "x y" => {
                type: "string",
              },
            },
          },
        },
      }

      expect(described_class.convert(schema)).to eq(
        '["full-name"]' => "string",
        '["a.b"]' => "boolean",
        "a" => "object",
        "a.b" => "integer",
        'a["x y"]' => "string",
      )
    end

    it "does not narrow mixed structural unions" do
      schema = {
        type: "object",
        properties: {
          object_or_string: {
            type: %w[object string],
            properties: {
              id: {
                type: "integer",
              },
            },
          },
          array_or_string: {
            type: %w[array string],
            items: {
              type: "integer",
            },
          },
          nullable_object: {
            type: %w[object null],
            properties: {
              id: {
                type: "integer",
              },
            },
          },
          nullable_array: {
            type: %w[array null],
            items: {
              type: "integer",
            },
          },
        },
      }

      expect(described_class.convert(schema)).to eq(
        "object_or_string" => "object|string",
        "array_or_string" => "array|string",
        "nullable_object" => "object|null",
        "nullable_object.id" => "integer",
        "nullable_array" => "array<integer>|null",
      )
    end

    it "combines anyOf alternatives into a single display schema" do
      schema = {
        "$schema" => "https://json-schema.org/draft/2020-12/schema",
        "anyOf" => [
          {
            type: "object",
            properties: {
              value: {
                type: "string",
              },
              left_only: {
                type: "boolean",
              },
            },
          },
          {
            type: "object",
            properties: {
              value: {
                type: "integer",
              },
              right_only: {
                type: "boolean",
              },
            },
          },
        ],
      }

      expect(described_class.convert(schema)).to eq(
        "value" => "string|integer",
        "left_only" => "boolean",
        "right_only" => "boolean",
      )
    end

    it "keeps nested anyOf alternatives when combining branches" do
      schema = {
        "anyOf" => [
          {
            type: "object",
            properties: {
              value: {
                "anyOf" => [{ type: "string" }, { type: "integer" }],
              },
            },
          },
          { type: "object", properties: { value: { type: "boolean" } } },
        ],
      }

      expect(described_class.convert(schema)).to eq("value" => "string|integer|boolean")
    end
  end
end
