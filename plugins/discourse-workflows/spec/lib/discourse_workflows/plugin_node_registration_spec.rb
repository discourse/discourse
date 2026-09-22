# frozen_string_literal: true

RSpec.describe DiscourseWorkflows do
  describe ".register_node" do
    let(:event_name) { :plugin_node_registration_test_event }
    let(:plugin) { Plugin::Instance.new }
    let(:handled) { [] }

    let(:node_class) do
      Class.new(DiscourseWorkflows::NodeType) do
        description(
          name: "trigger:plugin_node_registration_test",
          version: "1.0",
          event: :plugin_node_registration_test_event,
        )

        def initialize(payload, *)
          super(parameters: {})
          @payload = payload
        end

        def output
          { payload: @payload }
        end
      end
    end

    before do
      DiscourseWorkflows.node_registration_ready = true
      allow(DiscourseWorkflows::EventListener).to receive(:handle) do |klass, *args|
        handled << [klass, args]
      end
    end

    after do
      DiscourseEvent.all_off(event_name)
      unregister_workflow_nodes(node_class)
    end

    it "subscribes the trigger event for a node registered by another plugin" do
      plugin.register_discourse_workflows_node(node_class)

      DiscourseEvent.trigger(event_name, "payload")

      expect(handled).to eq([[node_class, ["payload"]]])
    end

    it "subscribes a node contributed through the deferred block form" do
      DiscourseWorkflows.node_registration_ready = false
      registered = node_class
      plugin.register_discourse_workflows_node { registered }

      allow(Discourse).to receive(:plugins).and_return([plugin])
      DiscourseWorkflows.node_registration_ready = true
      DiscourseWorkflows.flush_plugin_node_registrations!

      DiscourseEvent.trigger(event_name, "payload")

      expect(handled).to eq([[node_class, ["payload"]]])
    end

    it "subscribes under the symbol DiscourseEvent key when the event is declared as a string" do
      string_event_class =
        Class.new(DiscourseWorkflows::NodeType) do
          description(
            name: "trigger:plugin_node_registration_string_event_test",
            version: "1.0",
            event: "plugin_node_registration_test_event",
          )
        end

      plugin.register_discourse_workflows_node(string_event_class)

      DiscourseEvent.trigger(event_name, "payload")

      expect(handled).to eq([[string_event_class, ["payload"]]])
    ensure
      unregister_workflow_nodes(string_event_class)
    end

    it "subscribes only once when the same node is registered again" do
      plugin.register_discourse_workflows_node(node_class)
      Plugin::Instance.new.register_discourse_workflows_node(node_class)

      DiscourseEvent.trigger(event_name, "payload")

      expect(handled.size).to eq(1)
    end

    it "keeps ownership with the plugin that registered the node first" do
      plugin.register_discourse_workflows_node(node_class)
      Plugin::Instance.new.register_discourse_workflows_node(node_class)

      owners =
        DiscoursePluginRegistry._raw_discourse_workflows_nodes.select do |entry|
          entry[:value] == node_class
        end

      expect(owners.map { |entry| entry[:plugin] }).to eq([plugin])
    end

    it "stops dispatching while the owning plugin is disabled" do
      plugin.enabled_site_setting(:discourse_sample_plugin_enabled)
      SiteSetting.discourse_sample_plugin_enabled = false
      plugin.register_discourse_workflows_node(node_class)

      DiscourseEvent.trigger(event_name, "payload")
      expect(handled).to be_empty

      SiteSetting.discourse_sample_plugin_enabled = true
      DiscourseEvent.trigger(event_name, "payload")
      expect(handled).to eq([[node_class, ["payload"]]])
    ensure
      handler = plugin.instance_variable_get(:@discourse_workflows_node_cache_reset_handler)
      DiscourseEvent.off(:site_setting_changed, &handler) if handler
    end

    it "does not subscribe a node that declares no trigger event" do
      action_class =
        Class.new(DiscourseWorkflows::NodeType) do
          description(name: "action:plugin_node_registration_test", version: "1.0")
        end

      expect { plugin.register_discourse_workflows_node(action_class) }.not_to change {
        DiscourseEvent.events.values.sum(&:count)
      }
    ensure
      unregister_workflow_nodes(action_class)
    end
  end
end
