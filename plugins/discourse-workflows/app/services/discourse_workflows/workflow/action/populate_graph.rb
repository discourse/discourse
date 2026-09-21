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

      NodePacks::LifecycleLock.with_graph_write(nodes_data) { persist_graph(validator) }
    rescue NodePacks::LifecycleLock::MissingReferencesError => error
      NodePacks::LifecycleLock
        .missing_reference_messages(error.references)
        .each { |message| workflow.errors.add(:base, message) }
      false
    end

    private

    def persist_graph(validator)
      workflow.update(nodes: validator.nodes, connections: validator.connections)
    end
  end
end
