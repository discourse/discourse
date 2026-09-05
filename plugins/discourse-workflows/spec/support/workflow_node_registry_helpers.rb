# frozen_string_literal: true

module DiscourseWorkflows
  module WorkflowNodeRegistryHelpers
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

RSpec.configure { |config| config.include DiscourseWorkflows::WorkflowNodeRegistryHelpers }
