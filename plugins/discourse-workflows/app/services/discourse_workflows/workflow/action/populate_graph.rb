# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::Action::PopulateGraph < Service::ActionBase
    MAX_NODES = WorkflowGraphValidator::MAX_NODES

    option :workflow
    option :nodes_data
    option :connections_data

    def call
      validator = WorkflowGraphValidator.new(workflow:, nodes_data:, connections_data:)
      return false unless validator.valid?

      persist_graph(validator)
    end

    private

    def persist_graph(validator)
      workflow.update(nodes: validator.nodes, connections: validator.connections)
    end
  end
end
