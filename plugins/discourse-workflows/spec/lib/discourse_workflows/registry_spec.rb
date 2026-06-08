# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Registry do
  before { described_class.reset_indexes! }

  describe "plugin node registration hook" do
    it "registers a loaded node class" do
      plugin = Plugin::Instance.new
      node_class =
        Class.new(DiscourseWorkflows::NodeType) do
          description(name: "action:plugin_hook_direct_test", version: "1.0")
        end

      DiscourseWorkflows.node_registration_ready = true
      plugin.register_discourse_workflows_node(node_class)
      described_class.reset_indexes!

      expect(described_class.find_node_type("action:plugin_hook_direct_test")).to eq(node_class)
    ensure
      DiscoursePluginRegistry._raw_discourse_workflows_nodes.reject! do |entry|
        entry[:value] == node_class
      end
      described_class.reset_indexes!
    end

    it "defers a node registration block until workflow node registration is ready" do
      plugin = Plugin::Instance.new
      node_class = nil

      DiscourseWorkflows.node_registration_ready = false
      plugin.register_discourse_workflows_node do
        node_class =
          Class.new(DiscourseWorkflows::NodeType) do
            description(name: "action:plugin_hook_deferred_test", version: "1.0")
          end
      end

      expect(plugin.discourse_workflows_node_registrations.size).to eq(1)

      allow(Discourse).to receive(:plugins).and_return([plugin])
      DiscourseWorkflows.node_registration_ready = true
      DiscourseWorkflows.flush_plugin_node_registrations!
      described_class.reset_indexes!

      expect(described_class.find_node_type("action:plugin_hook_deferred_test")).to eq(node_class)
      expect(plugin.discourse_workflows_node_registrations).to be_empty
    ensure
      DiscourseWorkflows.node_registration_ready = true
      DiscoursePluginRegistry._raw_discourse_workflows_nodes.reject! do |entry|
        entry[:value] == node_class
      end
      described_class.reset_indexes!
    end

    it "resets registry indexes when the registering plugin is enabled or disabled" do
      plugin = Plugin::Instance.new
      plugin.enabled_site_setting(:discourse_sample_plugin_enabled)
      SiteSetting.discourse_sample_plugin_enabled = true
      node_class =
        Class.new(DiscourseWorkflows::NodeType) do
          description(name: "action:plugin_hook_enabled_test", version: "1.0")
        end

      DiscourseWorkflows.node_registration_ready = true
      plugin.register_discourse_workflows_node(node_class)
      described_class.reset_indexes!

      expect(described_class.find_node_type("action:plugin_hook_enabled_test")).to eq(node_class)

      SiteSetting.discourse_sample_plugin_enabled = false
      expect(described_class.find_node_type("action:plugin_hook_enabled_test")).to be_nil

      SiteSetting.discourse_sample_plugin_enabled = true
      expect(described_class.find_node_type("action:plugin_hook_enabled_test")).to eq(node_class)
    ensure
      if plugin
        handler = plugin.instance_variable_get(:@discourse_workflows_node_cache_reset_handler)
        DiscourseEvent.off(:site_setting_changed, &handler) if handler
      end
      SiteSetting.discourse_sample_plugin_enabled = true
      DiscoursePluginRegistry._raw_discourse_workflows_nodes.reject! do |entry|
        entry[:value] == node_class
      end
      described_class.reset_indexes!
    end

    it "reflects the current filtered registry without requiring an index reset" do
      plugin = Plugin::Instance.new
      node_class =
        Class.new(DiscourseWorkflows::NodeType) do
          description(name: "action:plugin_hook_filter_test", version: "1.0")
        end

      DiscoursePluginRegistry.register_discourse_workflows_node(node_class, plugin)

      expect(described_class.available_versions("action:plugin_hook_filter_test")).to eq(["1.0"])

      allow(plugin).to receive(:enabled?).and_return(false)

      expect(described_class.available_versions("action:plugin_hook_filter_test")).to eq([])
      expect(described_class.find_node_type("action:plugin_hook_filter_test")).to be_nil
      expect(
        described_class.available_versions(
          "action:plugin_hook_filter_test",
          include_disabled_plugins: true,
        ),
      ).to eq(["1.0"])
      expect(
        described_class.find_node_type(
          "action:plugin_hook_filter_test",
          include_disabled_plugins: true,
        ),
      ).to eq(node_class)
    ensure
      DiscoursePluginRegistry._raw_discourse_workflows_nodes.reject! do |entry|
        entry[:value] == node_class
      end
      described_class.reset_indexes!
    end
  end

  describe ".find_node_type" do
    it "finds a registered node type by identifier" do
      trigger = described_class.triggers.first
      expect(described_class.find_node_type(trigger.identifier)).to eq(trigger)
    end

    it "returns nil for unknown identifiers" do
      expect(described_class.find_node_type("trigger:nonexistent")).to be_nil
    end

    it "finds a registered node type by identifier and version" do
      v1 =
        Class.new(DiscourseWorkflows::NodeType) do
          description(name: "action:registry_versioned_test", version: "1.0")
        end
      v2 =
        Class.new(DiscourseWorkflows::NodeType) do
          description(name: "action:registry_versioned_test", version: "2.0")
        end

      DiscoursePluginRegistry.register_discourse_workflows_node(v1, Plugin::Instance.new)
      DiscoursePluginRegistry.register_discourse_workflows_node(v2, Plugin::Instance.new)
      described_class.reset_indexes!

      expect(
        described_class.find_node_type("action:registry_versioned_test", version: "1.0"),
      ).to eq(v1)
      expect(
        described_class.find_node_type("action:registry_versioned_test", version: "2.0"),
      ).to eq(v2)
      expect(described_class.available_versions("action:registry_versioned_test")).to eq(
        %w[1.0 2.0],
      )
      expect(described_class.latest_version("action:registry_versioned_test")).to eq("2.0")
    ensure
      DiscoursePluginRegistry._raw_discourse_workflows_nodes.reject! do |entry|
        [v1, v2].include?(entry[:value])
      end
      described_class.reset_indexes!
    end

    it "rejects duplicate node identifier and version registrations" do
      first =
        Class.new(DiscourseWorkflows::NodeType) do
          description(name: "action:registry_duplicate_test", version: "1.0")
        end
      duplicate =
        Class.new(DiscourseWorkflows::NodeType) do
          description(name: "action:registry_duplicate_test", version: "1.0")
        end

      DiscoursePluginRegistry.register_discourse_workflows_node(first, Plugin::Instance.new)
      DiscoursePluginRegistry.register_discourse_workflows_node(duplicate, Plugin::Instance.new)
      described_class.reset_indexes!

      expect { described_class.find_node_type("action:registry_duplicate_test") }.to raise_error(
        ArgumentError,
        "Duplicate workflow node type action:registry_duplicate_test v1.0",
      )
    ensure
      DiscoursePluginRegistry._raw_discourse_workflows_nodes.reject! do |entry|
        [first, duplicate].include?(entry[:value])
      end
      described_class.reset_indexes!
    end
  end
end
