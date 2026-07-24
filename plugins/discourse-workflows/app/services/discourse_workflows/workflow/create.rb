# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::Create
    include Service::Base

    params do
      attribute :name, :string
      attribute :nodes, default: -> { [] }
      attribute :connections, default: -> { {} }
      attribute :static_data, default: -> { {} }

      validates :name, presence: true, length: { maximum: 100 }
      validate :static_data_is_valid_map

      def static_data_is_valid_map
        return if DiscourseWorkflows::Workflow.valid_static_data_map?(static_data)

        errors.add(:static_data, :invalid)
      end
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows

    transaction do
      model :workflow, :create_workflow
      step :populate_graph
      model :workflow_version, :create_initial_snapshot
      step :index_dependencies
    end

    step :log
    step :expire_workflow_caches

    private

    def create_workflow(params:, guardian:)
      DiscourseWorkflows::Workflow.create(
        name: params.name,
        static_data: params.static_data,
        created_by: guardian.user,
        updated_by: guardian.user,
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

    def create_initial_snapshot(workflow:, guardian:)
      workflow.initial_snapshot!(user: guardian.user)
    end

    def index_dependencies(workflow:, workflow_version:)
      DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow, version: workflow_version)
    end

    def log(workflow:, guardian:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_workflow_created",
        subject: workflow.name,
        workflow_id: workflow.id,
      )
    end

    def expire_workflow_caches
      Workflow::Action::ExpireCaches.call
    end
  end
end
