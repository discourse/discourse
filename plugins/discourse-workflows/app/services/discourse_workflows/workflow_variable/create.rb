# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowVariable::Create
    include Service::Base

    params do
      attribute :workflow_id, :integer
      attribute :key, :string
      attribute :description, :string
      attribute :variable_type, :string
      attribute :type_options, default: -> { {} }

      validates :workflow_id, presence: true
      validates :key,
                presence: true,
                length: {
                  maximum: 100,
                },
                format: {
                  with: /\A[a-zA-Z_][a-zA-Z0-9_]*\z/,
                }
      validates :description, length: { maximum: 500 }, allow_nil: true
      validates :variable_type,
                presence: true,
                inclusion: {
                  in: DiscourseWorkflows::Variable::VARIABLE_TYPES,
                }
      validate :type_options_is_a_hash

      def type_options_is_a_hash
        errors.add(:type_options, :invalid) unless type_options.is_a?(Hash)
      end
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows

    lock(:workflow_id) do
      model :workflow

      transaction do
        model :variable, :create_variable
        model :workflow_version, :snapshot_workflow
        step :index_dependencies
      end
    end

    step :log_variable_creation

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::Workflow.find_by(id: params.workflow_id)
    end

    def create_variable(workflow:, params:, guardian:)
      workflow.variables.create(
        key: params.key,
        description: params.description,
        variable_type: params.variable_type,
        type_options: params.type_options,
        created_by: guardian.user,
      )
    end

    def snapshot_workflow(workflow:, guardian:)
      workflow.snapshot!(user: guardian.user)
    end

    def index_dependencies(workflow:, workflow_version:)
      DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow, version: workflow_version)
    end

    def log_variable_creation(variable:, guardian:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_workflow_variable_created",
        subject: variable.key,
      )
    end
  end
end
