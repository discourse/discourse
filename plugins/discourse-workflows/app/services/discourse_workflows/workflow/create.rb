# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::Create
    include Service::Base

    params do
      attribute :name, :string
      attribute :nodes, default: -> { [] }
      attribute :connections, default: -> { [] }
      attribute :sticky_notes, default: -> { [] }

      before_validation { self.nodes = Array.wrap(nodes).select { it.is_a?(Hash) } }
      before_validation { self.connections = Array.wrap(connections).select { it.is_a?(Hash) } }
      before_validation { self.sticky_notes = Array.wrap(sticky_notes).select { it.is_a?(Hash) } }

      validates :name, presence: true
    end

    transaction do
      model :workflow, :create_workflow
      step :populate_graph
    end

    step :log
    step :clear_site_cache

    private

    def create_workflow(params:, guardian:)
      DiscourseWorkflows::Workflow.create(
        name: params.name,
        created_by: guardian.user,
        enabled: false,
        sticky_notes: params.sticky_notes,
      )
    end

    def populate_graph(workflow:, params:)
      result =
        Workflow::Action::PopulateGraph.call(
          workflow:,
          nodes_data: params.nodes,
          connections_data: params.connections,
        )
      fail!(workflow.errors.full_messages) if result == false
    end

    def log(workflow:, guardian:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_workflow_created",
        subject: workflow.name,
        workflow_id: workflow.id,
      )
    end

    def clear_site_cache
      Site.clear_cache
    end
  end
end
