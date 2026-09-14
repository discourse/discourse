# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowVariable::ImportDefinitions
    include Service::Base

    params do
      attribute :workflow_id, :integer
      attribute :variables, default: -> { [] }

      validates :workflow_id, presence: true
      validate :variables_is_an_array_of_hashes

      def variables_is_an_array_of_hashes
        return if variables.is_a?(Array) && variables.all? { |field| field.is_a?(Hash) }

        errors.add(:variables, :invalid)
      end
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows

    lock(:workflow_id) do
      model :workflow

      transaction do
        model :imported_variables, :import_variables
        only_if(:imported_any_variables) do
          model :workflow_version, :snapshot_workflow
          step :index_dependencies
        end
      end
    end

    step :log_variables_import

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::Workflow.find_by(id: params.workflow_id)
    end

    # Skips (rather than overwrites) any imported variable whose key already
    # exists on this workflow, so an import can never silently clobber an
    # existing variable's type/options.
    def import_variables(workflow:, params:, guardian:)
      existing_keys = workflow.variables.pluck(:key).to_set
      created = []
      skipped = []

      Array(params.variables).each do |raw_field|
        field = raw_field.with_indifferent_access
        key = field["key"].presence
        next if key.blank?

        if existing_keys.include?(key)
          skipped << key
          next
        end

        new_variable =
          workflow.variables.create(
            key: key,
            description: field["description"],
            variable_type: field["variable_type"].presence || "string",
            type_options: field["type_options"].is_a?(Hash) ? field["type_options"] : {},
            created_by: guardian.user,
          )

        if new_variable.persisted?
          created << new_variable
          existing_keys << key
        else
          skipped << key
        end
      end

      { created:, skipped: }
    end

    def imported_any_variables(imported_variables:)
      imported_variables[:created].any?
    end

    def snapshot_workflow(workflow:, guardian:)
      workflow.snapshot!(user: guardian.user)
    end

    def index_dependencies(workflow:, workflow_version:)
      DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow, version: workflow_version)
    end

    def log_variables_import(workflow:, imported_variables:, guardian:)
      return if imported_variables[:created].empty?

      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_workflow_variables_imported",
        subject: workflow.name,
        created_count: imported_variables[:created].size,
        skipped_count: imported_variables[:skipped].size,
      )
    end
  end
end
