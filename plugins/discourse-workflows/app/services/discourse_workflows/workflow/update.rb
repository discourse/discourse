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

      before_validation { self.nodes = Array.wrap(nodes).select { it.is_a?(Hash) } if nodes }

      before_validation do
        self.connections = Array.wrap(connections).select { it.is_a?(Hash) } if connections
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
      workflow.update!(name: params.name, enabled: params.enabled, updated_by: guardian.user)
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
