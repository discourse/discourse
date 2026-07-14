# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::TriggerRuntime do
  describe ".activate_workflow!" do
    it "does not invoke passive triggers during activation" do
      passive_trigger_class =
        Class.new(DiscourseWorkflows::NodeType) do
          description(name: "trigger:passive_activation_test")

          def trigger(_trigger_ctx)
            raise "passive trigger was activated"
          end
        end

      DiscoursePluginRegistry.register_discourse_workflows_node(
        passive_trigger_class,
        Plugin::Instance.new,
      )
      DiscourseWorkflows::Registry.reset_indexes!

      graph =
        build_workflow_graph do |graph_builder|
          graph_builder.node "trigger-1", "trigger:passive_activation_test"
        end
      workflow = Fabricate(:discourse_workflows_workflow, published: true, **graph)

      expect {
        described_class.activate_workflow!(workflow, workflow_version: workflow.active_version)
      }.not_to raise_error
    ensure
      DiscoursePluginRegistry._raw_discourse_workflows_nodes.reject! do |entry|
        entry[:value] == passive_trigger_class
      end
      DiscourseWorkflows::NodeType.registered_nodes.delete(passive_trigger_class)
      DiscourseWorkflows::Registry.reset_indexes!
    end
  end
end
