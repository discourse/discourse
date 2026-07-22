# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::NodeType do
  around do |example|
    nodes_before = described_class.registered_nodes.dup
    example.run
    described_class.registered_nodes.replace(nodes_before)
  end

  describe ".webhooks" do
    it "normalizes webhook descriptors to symbol keys" do
      klass =
        Class.new(described_class) do
          description(
            webhooks: [
              {
                "path" => "status",
                "http_method" => "GET",
                "restart_webhook" => true,
                "node_type" => "form",
              },
            ],
          )
        end

      expect(klass.webhooks).to contain_exactly(
        path: "status",
        http_method: "GET",
        restart_webhook: true,
        node_type: "form",
      )
    end
  end

  describe ".waiting_webhook_for" do
    it "finds a matching restart webhook descriptor" do
      klass =
        Class.new(described_class) do
          description(
            webhooks: [{ path: "", http_method: "POST", restart_webhook: true, node_type: "form" }],
          )
        end

      expect(klass.waiting_webhook_for(http_method: "post", path: "", node_type: "form")).to eq(
        path: "",
        http_method: "POST",
        restart_webhook: true,
        node_type: "form",
      )
    end

    it "ignores non-restart webhook descriptors" do
      klass =
        Class.new(described_class) do
          description(webhooks: [{ path: "", http_method: "POST", node_type: "form" }])
        end

      expect(klass.waiting_webhook_for(http_method: "POST", path: "", node_type: "form")).to be_nil
    end
  end

  describe ".branching?" do
    it "returns false when single output" do
      expect(described_class.branching?).to eq(false)
    end

    it "returns true when multiple outputs" do
      klass =
        Class.new(described_class) do
          description(outputs: [{ key: "true", label_key: "t" }, { key: "false", label_key: "f" }])
        end
      expect(klass.branching?).to eq(true)
    end
  end

  describe ".available?" do
    it "can be overridden by subclass" do
      klass =
        Class.new(described_class) { description(name: "action:unavailable", available: false) }
      expect(klass.available?).to eq(false)
    end
  end

  describe ".unavailable_reason_key" do
    it "evaluates callable unavailable reason descriptors" do
      reason = "discourse_workflows.node_unavailable.dynamic_reason"
      klass =
        Class.new(described_class) do
          description(
            name: "action:dynamic_unavailable_reason",
            unavailable_reason_key: -> { reason },
          )
        end

      expect(klass.unavailable_reason_key).to eq(reason)
    end
  end

  describe ".output_contracts" do
    let(:declared_schema) do
      {
        "$schema" => DiscourseWorkflows::Schema::DRAFT_URI,
        "type" => "object",
        "properties" => {
          "result" => {
            "type" => "object",
            "properties" => {
              "value" => {
                "type" => "string",
              },
            },
          },
        },
      }
    end

    let(:node_class) do
      schema = declared_schema
      Class.new(described_class) do
        description(
          name: "action:schema_test",
          output_contracts: [
            { schema: schema, mode: :merge, display_options: { show: { operation: ["run"] } } },
          ],
        )
      end
    end

    it "exposes one contract per output position" do
      expect(node_class.output_contracts).to contain_exactly(
        schema: declared_schema,
        mode: :merge,
        display_options: {
          show: {
            operation: ["run"],
          },
        },
        variants: [],
      )
    end

    it "resolves output schema against configuration and input" do
      input_schema = {
        "$schema" => DiscourseWorkflows::Schema::DRAFT_URI,
        "type" => "object",
        "properties" => {
          "source" => {
            "type" => "object",
            "properties" => {
              "id" => {
                "type" => "integer",
              },
            },
          },
        },
      }

      expect(
        node_class.output_schemas({ "operation" => "run" }, input_schemas: [input_schema]),
      ).to eq([DiscourseWorkflows::Schema.merge(input_schema, declared_schema)])
    end

    it "resolves an unknown output when the base contract is hidden" do
      input_schema = {
        "$schema" => DiscourseWorkflows::Schema::DRAFT_URI,
        "type" => "object",
        "properties" => {
          "source" => {
            "type" => "string",
          },
        },
      }

      expect(
        node_class.output_schemas({ "operation" => "other" }, input_schemas: [input_schema]),
      ).to eq([{}])
    end

    it "uses the first visible output contract variant before the base contract" do
      input_schema = {
        "$schema" => DiscourseWorkflows::Schema::DRAFT_URI,
        "type" => "object",
        "properties" => {
          "source" => {
            "type" => "string",
          },
        },
      }
      replacement_schema = {
        "$schema" => DiscourseWorkflows::Schema::DRAFT_URI,
        "type" => "object",
        "properties" => {
          "response" => {
            "type" => "boolean",
          },
        },
      }
      klass =
        Class.new(described_class) do
          description(
            name: "action:variant_schema",
            output_contracts: [
              {
                mode: :passthrough,
                variants: [
                  { schema: replacement_schema, display_options: { show: { mode: ["replace"] } } },
                ],
              },
            ],
          )
        end

      expect(klass.output_schemas({ "mode" => "replace" }, input_schemas: [input_schema])).to eq(
        [replacement_schema],
      )
      expect(klass.output_schemas({ "mode" => "pass" }, input_schemas: [input_schema])).to eq(
        [input_schema],
      )
    end

    it "keeps an empty declaration as the no-declaration sentinel" do
      expect(described_class.output_contracts).to contain_exactly(
        schema: {
        },
        mode: :replace,
        display_options: {
        },
        variants: [],
      )
    end

    it "declares valid JSON Schema for every registered node contract" do
      schemas =
        DiscourseWorkflows::Registry
          .nodes(include_disabled_plugins: true)
          .flat_map(&:output_contracts)
          .flat_map { |contract| [contract, *contract.fetch(:variants)] }
          .map { |contract| contract.fetch(:schema) }

      expect(schemas).to all(be_a(Hash))
    end

    it "rejects unknown contract modes at declaration time" do
      klass =
        Class.new(described_class) do
          description(name: "action:bad_mode", output_contracts: [{ mode: :passthru }])
        end

      expect { klass.output_contracts }.to raise_error(
        ArgumentError,
        "Unknown output schema mode: :passthru",
      )
    end

    it "rejects flat path declarations" do
      klass =
        Class.new(described_class) do
          description(
            name: "action:flat_schema",
            output_contracts: [{ schema: { "result.value" => "string" } }],
          )
        end

      expect { klass.output_contracts }.to raise_error(
        ArgumentError,
        "Output schema must declare JSON Schema Draft 2020-12",
      )
    end

    it "requires one schema contract per output position" do
      klass =
        Class.new(described_class) do
          description(
            name: "condition:schema_count",
            outputs: %i[true false],
            output_contracts: [{}],
          )
        end

      expect { klass.output_contracts }.to raise_error(
        ArgumentError,
        "condition:schema_count declares 1 output contracts for 2 outputs",
      )
    end
  end

  describe ".normalize_category_ids" do
    it "coerces scalars, arrays, and mixed values to unique integer ids" do
      expect(described_class.normalize_category_ids(nil)).to eq([])
      expect(described_class.normalize_category_ids("")).to eq([])
      expect(described_class.normalize_category_ids([])).to eq([])
      expect(described_class.normalize_category_ids("12")).to eq([12])
      expect(described_class.normalize_category_ids(12)).to eq([12])
      expect(described_class.normalize_category_ids(["12", 3, " 12 "])).to eq([12, 3])
      expect(described_class.normalize_category_ids([nil, ""])).to eq([])
    end

    it "coerces unresolved expression strings to a non-matching id" do
      expect(described_class.normalize_category_ids(["=$json.category_id"])).to eq([0])
    end
  end

  describe ".category_ids_parameter" do
    def trigger_context(parameters)
      DiscourseWorkflows::TriggerNodeContext.new({ "parameters" => parameters })
    end

    it "reads category_ids when present" do
      expect(
        described_class.category_ids_parameter(trigger_context("category_ids" => %w[1 2])),
      ).to eq([1, 2])
    end

    it "falls back to the legacy category_id parameter" do
      expect(described_class.category_ids_parameter(trigger_context("category_id" => "3"))).to eq(
        [3],
      )
    end

    it "prefers category_ids over a stale category_id" do
      expect(
        described_class.category_ids_parameter(
          trigger_context("category_ids" => ["1"], "category_id" => "3"),
        ),
      ).to eq([1])
    end

    it "returns an empty list when neither parameter is set" do
      expect(described_class.category_ids_parameter(trigger_context({}))).to eq([])
    end
  end

  describe ".matches_category_ids?" do
    fab!(:parent_category, :category)
    fab!(:subcategory) { Fabricate(:category, parent_category: parent_category) }
    fab!(:other_category, :category)

    it "matches everything when no categories are configured" do
      expect(described_class.matches_category_ids?(subcategory.id, [])).to eq(true)
      expect(described_class.matches_category_ids?(nil, [])).to eq(true)
    end

    it "expands subcategories by default" do
      expect(described_class.matches_category_ids?(subcategory.id, [parent_category.id])).to eq(
        true,
      )
      expect(described_class.matches_category_ids?(subcategory.id, [other_category.id])).to eq(
        false,
      )
    end

    it "matches exactly when include_subcategories is false" do
      expect(
        described_class.matches_category_ids?(
          subcategory.id,
          [parent_category.id],
          include_subcategories: false,
        ),
      ).to eq(false)
      expect(
        described_class.matches_category_ids?(
          parent_category.id,
          [parent_category.id],
          include_subcategories: false,
        ),
      ).to eq(true)
    end

    it "expands subcategories when include_subcategories is nil" do
      expect(
        described_class.matches_category_ids?(
          subcategory.id,
          [parent_category.id],
          include_subcategories: nil,
        ),
      ).to eq(true)
    end

    it "matches against the union of all configured categories" do
      expect(
        described_class.matches_category_ids?(
          subcategory.id,
          [other_category.id, parent_category.id],
        ),
      ).to eq(true)
    end
  end

  describe ".expand_subcategory_ids" do
    fab!(:parent_category, :category)
    fab!(:subcategory) { Fabricate(:category, parent_category: parent_category) }
    fab!(:other_category, :category)

    it "returns the union of each category's subtree" do
      expect(
        described_class.expand_subcategory_ids([parent_category.id, other_category.id]),
      ).to contain_exactly(parent_category.id, subcategory.id, other_category.id)
    end
  end

  describe "#with_paired_item" do
    it "adds normalized paired item metadata to an item" do
      node = described_class.new
      item = { "json" => { "name" => "Ada" } }

      expect(node.send(:with_paired_item, item, { item: 1 })).to eq(
        "json" => {
          "name" => "Ada",
        },
        "pairedItem" => {
          "item" => 1,
        },
      )
    end
  end
end
