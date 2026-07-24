# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Schema do
  let(:input_schema) do
    {
      "$schema" => described_class::DRAFT_URI,
      "type" => "object",
      "properties" => {
        "source" => {
          "type" => "string",
        },
        "shared" => {
          "type" => "object",
          "properties" => {
            "kept" => {
              "type" => "string",
            },
          },
        },
      },
    }
  end

  let(:output_schema) do
    {
      "$schema" => described_class::DRAFT_URI,
      "type" => "object",
      "properties" => {
        "shared" => {
          "type" => "object",
          "properties" => {
            "added" => {
              "type" => "boolean",
            },
          },
        },
      },
    }
  end

  describe "reusable schema constants" do
    it "exposes reusable basic user and group properties" do
      property_types =
        {
          "user" => described_class::BASIC_USER_PROPERTIES,
          "group" => described_class::BASIC_GROUP_PROPERTIES,
        }.transform_values do |properties|
          properties.transform_values { |property| property.fetch("type") }
        end

      expect(property_types).to eq(
        "user" => {
          "id" => "integer",
          "username" => "string",
          "name" => %w[string null],
          "avatar_template" => "string",
        },
        "group" => {
          "id" => "integer",
          "name" => "string",
          "full_name" => %w[string null],
          "automatic" => "boolean",
        },
      )
    end

    it "defines reusable schemas as valid Draft 2020-12 declarations" do
      schemas =
        described_class.constants.grep(/_SCHEMA\z/).map { |name| described_class.const_get(name) }

      expect(schemas).to all(
        satisfy do |schema|
          schema["$schema"] == described_class::DRAFT_URI && JSONSchemer.valid_schema?(schema)
        end,
      )
    end
  end

  describe ".normalize" do
    it "accepts valid Draft 2020-12 object schemas and stringifies keys" do
      schema = {
        "$schema": described_class::DRAFT_URI,
        type: "object",
        properties: {
          value: {
            type: "string",
          },
        },
      }

      expect(described_class.normalize(schema)).to eq(
        "$schema" => described_class::DRAFT_URI,
        "type" => "object",
        "properties" => {
          "value" => {
            "type" => "string",
          },
        },
      )
    end

    it "keeps an empty hash as the no-declaration sentinel" do
      expect(described_class.normalize({})).to eq({})
    end

    it "rejects non-object declarations" do
      expect { described_class.normalize("string") }.to raise_error(
        ArgumentError,
        "Output schema must be a JSON Schema object",
      )
    end

    it "rejects declarations without a Draft 2020-12 marker" do
      expect { described_class.normalize("result.value" => "string") }.to raise_error(
        ArgumentError,
        "Output schema must declare JSON Schema Draft 2020-12",
      )
    end

    it "rejects invalid JSON Schema declarations" do
      schema = {
        "$schema" => described_class::DRAFT_URI,
        "type" => "object",
        "properties" => {
          "value" => {
            "type" => 12,
          },
        },
      }

      expect { described_class.normalize(schema) }.to raise_error(ArgumentError)
    end
  end

  describe ".merge" do
    it "combines disjoint object schemas" do
      merged = described_class.merge(input_schema, output_schema)

      expect(merged.dig("properties", "source", "type")).to eq("string")
      expect(merged.dig("properties", "shared", "properties").keys).to contain_exactly(
        "kept",
        "added",
      )
    end

    it "replaces conflicting non-object properties wholesale" do
      left = described_class.document("value" => { "type" => "string", "format" => "date-time" })
      right = described_class.document("value" => { "type" => "integer" })

      expect(described_class.merge(left, right).dig("properties", "value")).to eq(
        "type" => "integer",
      )
    end

    it "unions required fields" do
      left = input_schema.merge("required" => ["source"])
      right = output_schema.merge("required" => ["shared"])

      expect(described_class.merge(left, right)["required"]).to eq(%w[source shared])
    end

    it "ignores empty schemas" do
      expect(described_class.merge({}, input_schema, {})).to eq(input_schema)
      expect(described_class.merge({}, {})).to eq({})
    end
  end

  describe ".union" do
    it "expresses alternatives as anyOf" do
      expect(described_class.union(input_schema, output_schema)).to eq(
        "$schema" => described_class::DRAFT_URI,
        "anyOf" => [input_schema, output_schema],
      )
    end

    it "collapses identical alternatives" do
      expect(described_class.union(input_schema, input_schema)).to eq(input_schema)
    end

    it "flattens nested anyOf alternatives" do
      third = described_class.document("extra" => { "type" => "boolean" })

      expect(
        described_class.union(described_class.union(input_schema, output_schema), third),
      ).to eq(
        "$schema" => described_class::DRAFT_URI,
        "anyOf" => [input_schema, output_schema, third],
      )
    end

    it "becomes unknown when any alternative is unknown" do
      expect(described_class.union(input_schema, {})).to eq({})
      expect(described_class.union).to eq({})
    end
  end

  describe ".resolve" do
    it "replaces the input schema by default" do
      expect(
        described_class.resolve(output_schema, mode: :replace, input_schema: input_schema),
      ).to eq(output_schema)
    end

    it "passes the input schema through" do
      expect(
        described_class.resolve(output_schema, mode: :passthrough, input_schema: input_schema),
      ).to eq(input_schema)
    end

    it "preserves distinct input properties and replaces colliding root properties on merge" do
      result = described_class.resolve(output_schema, mode: :merge, input_schema: input_schema)

      expect(result.dig("properties", "source", "type")).to eq("string")
      expect(result.dig("properties", "shared", "properties").keys).to eq(["added"])
    end

    it "keeps the declaration when merging over an unknown input" do
      expect(described_class.resolve(output_schema, mode: :merge, input_schema: {})).to eq(
        output_schema,
      )
    end

    it "unions alternative output schemas" do
      expect(
        described_class.resolve(output_schema, mode: :union, input_schema: input_schema),
      ).to eq("$schema" => described_class::DRAFT_URI, "anyOf" => [input_schema, output_schema])
    end

    it "distributes a merge over anyOf input alternatives and stays idempotent" do
      union = described_class.union(input_schema, output_schema)
      declared = described_class.document("extra" => { "type" => "boolean" })

      result = described_class.resolve(declared, mode: :merge, input_schema: union)

      expect(result["anyOf"].length).to eq(2)
      expect(result["anyOf"]).to all(
        satisfy { |branch| branch.dig("properties", "extra") == { "type" => "boolean" } },
      )
      expect(described_class.resolve(declared, mode: :merge, input_schema: result)).to eq(result)
    end

    it "rejects unknown output schema modes" do
      expect { described_class.resolve(output_schema, mode: :append) }.to raise_error(
        ArgumentError,
        "Unknown output schema mode: :append",
      )
    end
  end

  describe ".infer" do
    it "infers a JSON Schema from sample item JSON" do
      schema =
        described_class.infer(
          "custom" => {
            "id" => 1,
            "score" => 1.5,
            "enabled" => true,
            "labels" => ["important", nil],
            "missing" => nil,
          },
        )

      expect(schema).to eq(
        "type" => "object",
        "properties" => {
          "custom" => {
            "type" => "object",
            "properties" => {
              "id" => {
                "type" => "integer",
              },
              "score" => {
                "type" => "number",
              },
              "enabled" => {
                "type" => "boolean",
              },
              "labels" => {
                "type" => "array",
                "items" => {
                  "anyOf" => [{ "type" => "string" }, { "type" => "null" }],
                },
              },
              "missing" => {
                "type" => "null",
              },
            },
          },
        },
      )
    end

    it "leaves empty array items unconstrained and collapses homogeneous arrays" do
      schema = described_class.infer("empty" => [], "same" => [1, 2])

      expect(schema.dig("properties", "empty")).to eq("type" => "array")
      expect(schema.dig("properties", "same")).to eq(
        "type" => "array",
        "items" => {
          "type" => "integer",
        },
      )
    end

    it "returns the unknown sentinel without sample fields" do
      expect(described_class.infer({})).to eq({})
      expect(described_class.infer("not a hash")).to eq({})
    end
  end

  describe ".visible?" do
    it "supports show and hide condition operators", :aggregate_failures do
      display_options = {
        show: {
          operation: ["run"],
        },
        hide: {
          selection: [{ condition: { exists: false } }],
        },
      }

      expect(described_class.visible?(display_options, operation: "run", selection: [1])).to eq(
        true,
      )
      expect(described_class.visible?(display_options, operation: "run", selection: [])).to eq(
        false,
      )
      expect(described_class.visible?(display_options, operation: "skip", selection: [1])).to eq(
        false,
      )
    end
  end

  describe ".resolve_graph" do
    it "propagates declared schemas through connected nodes" do
      graph =
        build_workflow_graph do |builder|
          builder.node "post-created", "trigger:post_created"
          builder.node "filter", "condition:filter"
          builder.connect "post-created", "filter"
        end

      resolution = described_class.resolve_graph(graph[:nodes], graph[:connections])
      filter_schema = resolution[:output_schemas]["filter"][0]

      expect(filter_schema.dig("properties", "post", "properties", "id", "type")).to eq("integer")
      expect(filter_schema.dig("properties", "user", "properties", "username", "type")).to eq(
        "string",
      )
    end

    it "resolves unregistered node type versions to unknown schemas and keeps downstream unions unknown" do
      trigger_schema = described_class.document("value" => { "type" => "string" })
      trigger_class =
        Class.new(DiscourseWorkflows::NodeType) do
          description(
            name: "trigger:schema_version_test",
            version: "1.0",
            output_contracts: [{ schema: trigger_schema }],
          )
        end
      join_class =
        Class.new(DiscourseWorkflows::NodeType) do
          description(
            name: "action:schema_version_join_test",
            version: "1.0",
            output_contracts: [{ mode: :passthrough }],
          )
        end
      DiscoursePluginRegistry.register_discourse_workflows_node(trigger_class, Plugin::Instance.new)
      DiscoursePluginRegistry.register_discourse_workflows_node(join_class, Plugin::Instance.new)
      DiscourseWorkflows::Registry.reset_indexes!
      graph =
        build_workflow_graph do |builder|
          builder.node "current", "trigger:schema_version_test"
          builder.node "stale", "trigger:schema_version_test"
          builder.node "join", "action:schema_version_join_test"
          builder.connect "current", "join"
          builder.connect "stale", "join"
        end
      graph[:nodes].find { |node| node["id"] == "stale" }["typeVersion"] = "9.0"

      resolution = described_class.resolve_graph(graph[:nodes], graph[:connections])

      expect(resolution[:output_schemas]["current"]).to eq([trigger_schema])
      expect(resolution[:output_schemas]["stale"]).to eq([{}])
      expect(resolution[:output_schemas]["join"]).to eq([{}])
    ensure
      unregister_workflow_nodes(trigger_class, join_class)
    end

    it "resolves nodes without a typeVersion as the default version instead of the latest" do
      v1_schema = described_class.document("from_v1" => { "type" => "string" })
      v2_schema = described_class.document("from_v2" => { "type" => "string" })
      v1_class =
        Class.new(DiscourseWorkflows::NodeType) do
          description(
            name: "trigger:schema_default_version_test",
            version: "1.0",
            output_contracts: [{ schema: v1_schema }],
          )
        end
      v2_class =
        Class.new(DiscourseWorkflows::NodeType) do
          description(
            name: "trigger:schema_default_version_test",
            version: "2.0",
            output_contracts: [{ schema: v2_schema }],
          )
        end
      DiscoursePluginRegistry.register_discourse_workflows_node(v1_class, Plugin::Instance.new)
      DiscoursePluginRegistry.register_discourse_workflows_node(v2_class, Plugin::Instance.new)
      DiscourseWorkflows::Registry.reset_indexes!
      graph =
        build_workflow_graph do |builder|
          builder.node "legacy", "trigger:schema_default_version_test"
        end
      graph[:nodes].each { |node| node.delete("typeVersion") }

      resolution = described_class.resolve_graph(graph[:nodes], graph[:connections])

      expect(resolution[:output_schemas]["legacy"]).to eq([v1_schema])
    ensure
      unregister_workflow_nodes(v1_class, v2_class)
    end

    it "selects the source schema by output position" do
      schemas =
        %w[kept rejected].map { |field| described_class.document(field => { "type" => "boolean" }) }
      source_class =
        Class.new { define_singleton_method(:output_schemas) { |*, input_schemas:| schemas } }
      target_class =
        Class.new do
          define_singleton_method(:input_ports) { |*| [{}, {}] }
          define_singleton_method(:output_schemas) do |*, input_schemas:|
            [DiscourseWorkflows::Schema.union(*input_schemas.compact)]
          end
        end
      graph =
        build_workflow_graph do |builder|
          builder.node "source", "condition:test"
          builder.node "target", "action:test"
          builder.connect "source", "target", output: 1, input: 1
        end
      allow(DiscourseWorkflows::Registry).to receive(:find_node_type) do |identifier, version: nil|
        identifier == "condition:test" ? source_class : target_class
      end

      resolution = described_class.resolve_graph(graph[:nodes], graph[:connections])

      expect(resolution[:output_schemas]["source"]).to eq(schemas)
      expect(resolution[:input_schemas]["target"]).to eq([nil, schemas.second])
      expect(resolution[:output_schemas]["target"]).to eq([schemas.second])
    end

    it "joins alternative incoming schemas with anyOf" do
      left_schema = described_class.document("left" => { "type" => "string" })
      right_schema = described_class.document("right" => { "type" => "string" })
      node_class_for =
        lambda do |schema|
          Class.new do
            define_singleton_method(:output_schemas) do |*, input_schemas:|
              schema ? [schema] : [DiscourseWorkflows::Schema.union(*input_schemas.compact)]
            end
          end
        end
      node_classes = {
        "trigger:left" => node_class_for.call(left_schema),
        "trigger:right" => node_class_for.call(right_schema),
        "action:target" => node_class_for.call(nil),
      }
      graph =
        build_workflow_graph do |builder|
          builder.node "left", "trigger:left"
          builder.node "right", "trigger:right"
          builder.node "target", "action:target"
          builder.connect "left", "target"
          builder.connect "right", "target"
        end
      allow(DiscourseWorkflows::Registry).to receive(:find_node_type) do |identifier, version: nil|
        node_classes.fetch(identifier)
      end

      target_schema =
        described_class.resolve_graph(graph[:nodes], graph[:connections])[:output_schemas][
          "target"
        ][
          0
        ]

      expect(target_schema).to eq(
        "$schema" => described_class::DRAFT_URI,
        "anyOf" => [left_schema, right_schema],
      )
    end

    it "keeps a join unknown when any incoming branch has no declaration" do
      declared_schema = described_class.document("value" => { "type" => "string" })
      declared_class =
        Class.new do
          define_singleton_method(:output_schemas) { |*, input_schemas:| [declared_schema] }
        end
      unknown_class =
        Class.new { define_singleton_method(:output_schemas) { |*, input_schemas:| [{}] } }
      passthrough_class =
        Class.new do
          define_singleton_method(:output_schemas) do |*, input_schemas:|
            [DiscourseWorkflows::Schema.union(*input_schemas.compact)]
          end
        end
      node_classes = {
        "trigger:declared" => declared_class,
        "action:unknown" => unknown_class,
        "action:target" => passthrough_class,
      }
      graph =
        build_workflow_graph do |builder|
          builder.node "declared", "trigger:declared"
          builder.node "unknown", "action:unknown"
          builder.node "target", "action:target"
          builder.connect "declared", "target"
          builder.connect "unknown", "target"
        end
      allow(DiscourseWorkflows::Registry).to receive(:find_node_type) do |identifier, version: nil|
        node_classes.fetch(identifier)
      end

      resolution = described_class.resolve_graph(graph[:nodes], graph[:connections])

      expect(resolution[:output_schemas]["target"]).to eq([{}])
    end

    it "propagates an external declaration through a passthrough cycle" do
      trigger_schema = described_class.document("value" => { "type" => "string" })
      trigger_class =
        Class.new do
          define_singleton_method(:output_schemas) { |*, input_schemas:| [trigger_schema] }
        end
      passthrough_class =
        Class.new do
          define_singleton_method(:output_schemas) do |*, input_schemas:|
            [DiscourseWorkflows::Schema.union(*input_schemas.compact)]
          end
        end
      graph =
        build_workflow_graph do |builder|
          builder.node "cycle-a", "action:passthrough"
          builder.node "cycle-b", "action:passthrough"
          builder.node "trigger", "trigger:test"
          builder.connect "trigger", "cycle-a"
          builder.connect "cycle-a", "cycle-b"
          builder.connect "cycle-b", "cycle-a"
        end
      allow(DiscourseWorkflows::Registry).to receive(:find_node_type) do |identifier, version: nil|
        identifier == "trigger:test" ? trigger_class : passthrough_class
      end

      resolution = described_class.resolve_graph(graph[:nodes], graph[:connections])

      expect(resolution[:output_schemas].values_at("cycle-a", "cycle-b")).to all(
        eq([trigger_schema]),
      )
    end

    it "keeps a join unknown when another branch is an unseeded passthrough cycle" do
      trigger_schema = described_class.document("value" => { "type" => "string" })
      trigger_class =
        Class.new do
          define_singleton_method(:output_schemas) { |*, input_schemas:| [trigger_schema] }
        end
      passthrough_class =
        Class.new do
          define_singleton_method(:output_schemas) do |*, input_schemas:|
            [DiscourseWorkflows::Schema.union(*input_schemas.compact)]
          end
        end
      graph =
        build_workflow_graph do |builder|
          builder.node "cycle-a", "action:passthrough"
          builder.node "cycle-b", "action:passthrough"
          builder.node "target", "action:passthrough"
          builder.node "trigger", "trigger:test"
          builder.connect "cycle-a", "cycle-b"
          builder.connect "cycle-b", "cycle-a"
          builder.connect "cycle-a", "target"
          builder.connect "trigger", "target"
        end
      allow(DiscourseWorkflows::Registry).to receive(:find_node_type) do |identifier, version: nil|
        identifier == "trigger:test" ? trigger_class : passthrough_class
      end

      resolution = described_class.resolve_graph(graph[:nodes], graph[:connections])

      expect(resolution[:output_schemas]["target"]).to eq([{}])
    end

    it "converges when a merge contract participates in a cycle" do
      trigger_schema = described_class.document("value" => { "type" => "string" })
      declared_schema = described_class.document("extra" => { "type" => "boolean" })
      trigger_class =
        Class.new do
          define_singleton_method(:output_schemas) { |*, input_schemas:| [trigger_schema] }
        end
      merge_class =
        Class.new do
          define_singleton_method(:output_schemas) do |*, input_schemas:|
            [
              DiscourseWorkflows::Schema.resolve(
                declared_schema,
                mode: :merge,
                input_schema: DiscourseWorkflows::Schema.union(*input_schemas.compact),
              ),
            ]
          end
        end
      passthrough_class =
        Class.new do
          define_singleton_method(:output_schemas) do |*, input_schemas:|
            [DiscourseWorkflows::Schema.union(*input_schemas.compact)]
          end
        end
      node_classes = {
        "trigger:test" => trigger_class,
        "action:merge" => merge_class,
        "action:passthrough" => passthrough_class,
      }
      graph =
        build_workflow_graph do |builder|
          builder.node "trigger", "trigger:test"
          builder.node "merger", "action:merge"
          builder.node "loop-back", "action:passthrough"
          builder.connect "trigger", "merger"
          builder.connect "merger", "loop-back"
          builder.connect "loop-back", "merger"
        end
      allow(DiscourseWorkflows::Registry).to receive(:find_node_type) do |identifier, version: nil|
        node_classes.fetch(identifier)
      end

      merger_schema =
        described_class.resolve_graph(graph[:nodes], graph[:connections])[:output_schemas][
          "merger"
        ][
          0
        ]

      expect(merger_schema.dig("properties", "value", "type")).to eq("string")
      expect(merger_schema.dig("properties", "extra", "type")).to eq("boolean")
    end

    it "ignores self connections when resolving inputs" do
      trigger_schema = described_class.document("value" => { "type" => "string" })
      trigger_class =
        Class.new do
          define_singleton_method(:output_schemas) { |*, input_schemas:| [trigger_schema] }
        end
      passthrough_class =
        Class.new do
          define_singleton_method(:output_schemas) do |*, input_schemas:|
            [DiscourseWorkflows::Schema.union(*input_schemas.compact)]
          end
        end
      graph =
        build_workflow_graph do |builder|
          builder.node "trigger", "trigger:test"
          builder.node "looper", "action:passthrough"
          builder.connect "trigger", "looper"
          builder.connect "looper", "looper"
        end
      allow(DiscourseWorkflows::Registry).to receive(:find_node_type) do |identifier, version: nil|
        identifier == "trigger:test" ? trigger_class : passthrough_class
      end

      resolution = described_class.resolve_graph(graph[:nodes], graph[:connections])

      expect(resolution[:output_schemas]["looper"]).to eq([trigger_schema])
    end

    it "raises when a custom node contract cannot converge" do
      counter = 0
      diverging_class =
        Class.new do
          define_singleton_method(:output_schemas) do |*, input_schemas:|
            [DiscourseWorkflows::Schema.document("field_#{counter += 1}" => { "type" => "string" })]
          end
        end
      graph =
        build_workflow_graph do |builder|
          builder.node "cycle-a", "action:diverging"
          builder.node "cycle-b", "action:diverging"
          builder.connect "cycle-a", "cycle-b"
          builder.connect "cycle-b", "cycle-a"
        end
      allow(DiscourseWorkflows::Registry).to receive(:find_node_type) do |identifier, version: nil|
        diverging_class
      end

      expect { described_class.resolve_graph(graph[:nodes], graph[:connections]) }.to raise_error(
        ArgumentError,
        "Output schema graph did not converge",
      )
    end

    it "propagates a reverse-ordered chain of passthrough nodes" do
      trigger_schema = described_class.document("value" => { "type" => "string" })
      trigger_class =
        Class.new do
          define_singleton_method(:output_schemas) { |*, input_schemas:| [trigger_schema] }
        end
      passthrough_class =
        Class.new do
          define_singleton_method(:output_schemas) do |*, input_schemas:|
            [DiscourseWorkflows::Schema.union(*input_schemas.compact)]
          end
        end
      graph =
        build_workflow_graph do |builder|
          builder.node "step-3", "action:passthrough"
          builder.node "step-2", "action:passthrough"
          builder.node "step-1", "action:passthrough"
          builder.node "trigger", "trigger:test"
          builder.connect "trigger", "step-1"
          builder.connect "step-1", "step-2"
          builder.connect "step-2", "step-3"
        end
      allow(DiscourseWorkflows::Registry).to receive(:find_node_type) do |identifier, version: nil|
        identifier == "trigger:test" ? trigger_class : passthrough_class
      end

      resolution = described_class.resolve_graph(graph[:nodes], graph[:connections])

      expect(resolution[:output_schemas].values_at("step-1", "step-2", "step-3")).to all(
        eq([trigger_schema]),
      )
    end
  end
end
