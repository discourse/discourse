# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowVariable::Update
    include Service::Base

    params do
      attribute :workflow_id, :integer
      attribute :variable_id, :integer
      attribute :key, :string
      attribute :description, :string
      attribute :variable_type, :string
      attribute :type_options, default: -> { {} }

      validates :workflow_id, :variable_id, presence: true
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
      model :variable
      model :previous_definition, :capture_previous_definition
      only_if(:variable_type_or_options_changing) do
        policy :existing_value_compatible_with_new_type,
               class_name: WorkflowVariable::Policy::ExistingValueCompatibleWithNewType
      end

      transaction do
        model :variable, :save_variable
        only_if(:definition_changed) do
          model :workflow_version, :snapshot_workflow
          step :index_dependencies
        end
      end
    end

    step :log_variable_update

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::Workflow.find_by(id: params.workflow_id)
    end

    def fetch_variable(workflow:, params:)
      workflow.variables.find_by(id: params.variable_id)
    end

    def capture_previous_definition(variable:)
      variable.definition
    end

    def variable_type_or_options_changing(variable:, params:)
      variable.variable_type != params.variable_type || variable.type_options != params.type_options
    end

    def save_variable(variable:, params:)
      variable.tap do |v|
        v.assign_attributes(
          key: params.key,
          description: params.description,
          variable_type: params.variable_type,
          type_options: params.type_options,
        )
        v.save
      end
    end

    def definition_changed(variable:, previous_definition:)
      variable.definition != previous_definition
    end

    def snapshot_workflow(workflow:, guardian:)
      workflow.snapshot!(user: guardian.user)
    end

    def index_dependencies(workflow:, workflow_version:)
      DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow, version: workflow_version)
    end

    def log_variable_update(variable:, guardian:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_workflow_variable_updated",
        subject: variable.key,
      )
    end
  end
end
