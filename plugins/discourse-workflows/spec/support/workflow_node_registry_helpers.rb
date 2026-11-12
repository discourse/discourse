# frozen_string_literal: true

module DiscourseWorkflows
  module WorkflowNodeRegistryHelpers
    def register_versioned_workflow_nodes(identifier, v1_deprecation: nil)
      v1 =
        Class.new(NodeType) do
          description(name: identifier, version: "1.0")
          deprecated(**v1_deprecation) if v1_deprecation
        end
      v2 = Class.new(v1) { description(superclass.description.merge(version: "2.0")) }
      (@registered_workflow_nodes ||= []).push(v1, v2)
      [v1, v2].each do |node_class|
        DiscourseWorkflows.register_node(node_class, Plugin::Instance.new)
      end
      Registry.reset_indexes!
      [v1, v2]
    end

    def unregister_workflow_nodes(*node_classes)
      references = node_classes.compact.flat_map { |node_class| [node_class, node_class.name] }
      DiscoursePluginRegistry._raw_discourse_workflows_nodes.reject! do |entry|
        references.include?(entry[:value])
      end
      NodeType.registered_nodes.reject! { |node_class| node_classes.include?(node_class) }
      Registry.reset_indexes!
    end
  end
end

RSpec.configure do |config|
  config.include DiscourseWorkflows::WorkflowNodeRegistryHelpers
  config.after do
    unregister_workflow_nodes(*@registered_workflow_nodes) if @registered_workflow_nodes
  end
end
