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
