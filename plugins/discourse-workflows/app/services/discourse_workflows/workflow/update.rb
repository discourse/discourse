# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::Update
    include Service::Base

    params do
      attribute :workflow_id, :integer
      attribute :name, :string
      attribute :enabled, :boolean, default: false
      attribute :nodes
      attribute :connections
      attribute :sticky_notes

      before_validation { self.nodes = Array.wrap(nodes).select { it.is_a?(Hash) } if nodes }

      before_validation do
        self.connections = Array.wrap(connections).select { it.is_a?(Hash) } if connections
      end

      before_validation do
        self.sticky_notes = Array.wrap(sticky_notes).select { it.is_a?(Hash) } if sticky_notes
      end

      validates :workflow_id, presence: true
      validates :name, presence: true
    end

    model :workflow

    transaction do
      step :update_workflow
      step :populate_graph
    end

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::Workflow.find_by(id: params.workflow_id)
    end

    def update_workflow(workflow:, params:, guardian:)
      attrs = { name: params.name, enabled: params.enabled, updated_by: guardian.user }
      attrs[:sticky_notes] = params.sticky_notes if params.sticky_notes
      workflow.update!(**attrs)
    end

    def populate_graph(workflow:, params:)
      return if params.nodes.nil? && params.connections.nil?

      Workflow::Action::PopulateGraph.call(
        workflow:,
        nodes_data: params.nodes || [],
        connections_data: params.connections || [],
      )
    end
  end
end
