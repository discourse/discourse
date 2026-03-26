# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::Update
    include Service::Base

    params do
      attribute :workflow_id, :integer
      attribute :name, :string
      attribute :enabled, :boolean
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
      only_if(:graph_data_provided) { step :populate_graph }
    end

    step :clear_site_cache

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::Workflow.find_by(id: params.workflow_id)
    end

    def graph_data_provided(params:)
      !params.nodes.nil? || !params.connections.nil?
    end

    def update_workflow(workflow:, params:, guardian:)
      attrs = { name: params.name, updated_by: guardian.user }
      attrs[:enabled] = params.enabled unless params.enabled.nil?
      attrs[:sticky_notes] = params.sticky_notes if params.sticky_notes
      workflow.update!(**attrs)
    end

    def populate_graph(workflow:, params:)
      result =
        Workflow::Action::PopulateGraph.call(
          workflow:,
          nodes_data: params.nodes || [],
          connections_data: params.connections || [],
        )
      fail!(workflow.errors.full_messages) if result == false
    end

    def clear_site_cache
      Site.clear_cache
    end
  end
end
