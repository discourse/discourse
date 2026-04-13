# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::NodeTypeDescriptor do
  let(:trigger_class) do
    Class.new(DiscourseWorkflows::NodeType) do
      def self.identifier
        "trigger:test_event"
      end

      def self.icon
        "bolt"
      end

      def self.color
        "blue"
      end
    end
  end

  let(:action_class) do
    Class.new(DiscourseWorkflows::NodeType) do
      def self.identifier
        "action:do_thing"
      end
    end
  end

  let(:condition_class) do
    Class.new(DiscourseWorkflows::NodeType) do
      def self.identifier
        "condition:check"
      end
    end
  end

  let(:flow_class) do
    Class.new(DiscourseWorkflows::NodeType) do
      def self.identifier
        "flow:wait"
      end
    end
  end

  describe "#kind" do
    it "extracts the prefix from the identifier" do
      expect(trigger_class.kind).to eq("trigger")
      expect(action_class.kind).to eq("action")
    end
  end

  describe "#label_key" do
    it "builds the i18n key from the identifier" do
      expect(trigger_class.label_key).to eq("discourse_workflows.nodes.trigger:test_event")
    end
  end

  describe "#description_key" do
    it "builds the i18n key from the identifier" do
      expect(trigger_class.description_key).to eq(
        "discourse_workflows.node_descriptions.trigger:test_event",
      )
    end
  end

  describe "#property_i18n_prefix" do
    it "returns the default prefix" do
      expect(trigger_class.property_i18n_prefix).to eq("discourse_workflows")
    end
  end

  describe "#property_i18n_scope" do
    it "extracts the suffix from the identifier" do
      expect(trigger_class.property_i18n_scope).to eq("test_event")
    end
  end

  describe "#group" do
    it "returns 'triggers' for trigger nodes" do
      expect(trigger_class.group).to eq("triggers")
    end

    it "returns 'flow' for condition nodes" do
      expect(condition_class.group).to eq("flow")
    end

    it "returns 'flow' for flow nodes" do
      expect(flow_class.group).to eq("flow")
    end

    it "returns 'utilities' for action nodes" do
      expect(action_class.group).to eq("utilities")
    end
  end

  describe "#palette_group" do
    it "returns the group definition with id" do
      result = trigger_class.palette_group
      expect(result[:id]).to eq("triggers")
      expect(result[:icon]).to eq("bolt")
      expect(result[:label_key]).to eq("discourse_workflows.add_node.categories.triggers")
      expect(result[:order]).to eq(20)
    end
  end

  describe "#operations" do
    it "returns empty when no operation field" do
      expect(trigger_class.operations).to eq([])
    end

    it "returns empty when operation has single option" do
      klass =
        Class.new(DiscourseWorkflows::NodeType) do
          def self.identifier
            "action:single_op"
          end

          def self.property_schema
            { operation: { type: :options, options: %w[get] } }
          end
        end

      expect(klass.operations).to eq([])
    end

    it "returns labeled operations when multiple options exist" do
      klass =
        Class.new(DiscourseWorkflows::NodeType) do
          def self.identifier
            "action:multi_op"
          end

          def self.property_schema
            { operation: { type: :options, options: %w[get insert delete] } }
          end
        end

      ops = klass.operations
      expect(ops.length).to eq(3)
      expect(ops.first).to eq({ value: "get", label_key: "discourse_workflows.multi_op.get" })
    end
  end

  describe "#ports" do
    it "normalizes outputs into port definitions" do
      expect(trigger_class.ports).to eq([{ key: "main", primary: true }])
    end

    it "handles multiple outputs for branching nodes" do
      klass =
        Class.new(DiscourseWorkflows::NodeType) do
          def self.identifier
            "condition:branch"
          end

          def self.outputs
            [{ key: "true", label_key: "t" }, { key: "false", label_key: "f" }]
          end
        end

      ports = klass.ports
      expect(ports.length).to eq(2)
      expect(ports[0]).to eq({ key: "true", label_key: "t", primary: true })
      expect(ports[1]).to eq({ key: "false", label_key: "f", primary: false })
    end
  end

  describe "#capabilities" do
    it "returns capability hash for a simple node" do
      expect(trigger_class.capabilities).to eq(
        {
          branching: false,
          manually_triggerable: false,
          provides_current_user: false,
          result_mode: "items",
        },
      )
    end

    it "reflects branching and manually_triggerable" do
      klass =
        Class.new(DiscourseWorkflows::NodeType) do
          def self.identifier
            "trigger:manual"
          end

          def self.outputs
            %w[true false]
          end

          def self.manually_triggerable?
            true
          end
        end

      caps = klass.capabilities
      expect(caps[:branching]).to eq(true)
      expect(caps[:manually_triggerable]).to eq(true)
      expect(caps[:result_mode]).to eq("ports")
    end
  end

  describe "#ui_metadata" do
    it "assembles all UI fields" do
      result = trigger_class.ui_metadata
      expect(result[:icon]).to eq("bolt")
      expect(result[:color]).to eq("blue")
      expect(result[:label_key]).to eq("discourse_workflows.nodes.trigger:test_event")
      expect(result[:description_key]).to eq(
        "discourse_workflows.node_descriptions.trigger:test_event",
      )
      expect(result[:palette_group][:id]).to eq("triggers")
      expect(result[:property_i18n_prefix]).to eq("discourse_workflows")
      expect(result[:property_i18n_scope]).to eq("test_event")
    end

    it "omits nil values" do
      result = action_class.ui_metadata
      expect(result).not_to have_key(:icon)
      expect(result).not_to have_key(:color)
    end
  end
end
