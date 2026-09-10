# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowSettingField::ImportDefinitions
    include Service::Base

    params do
      attribute :workflow_id, :integer
      attribute :setting_fields, default: -> { [] }

      validates :workflow_id, presence: true
      validate :setting_fields_is_an_array_of_hashes

      def setting_fields_is_an_array_of_hashes
        return if setting_fields.is_a?(Array) && setting_fields.all? { |field| field.is_a?(Hash) }

        errors.add(:setting_fields, :invalid)
      end
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows

    lock(:workflow_id) do
      model :workflow

      transaction do
        model :imported_fields, :import_setting_fields
        only_if(:imported_any_fields) do
          model :workflow_version, :snapshot_workflow
          step :index_dependencies
        end
      end
    end

    step :log_setting_fields_import

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::Workflow.find_by(id: params.workflow_id)
    end

    # Skips (rather than overwrites) any imported field whose key already
    # exists on this workflow, so an import can never silently clobber an
    # existing field's type/options.
    def import_setting_fields(workflow:, params:)
      existing_keys = workflow.setting_fields.pluck(:key).to_set
      created = []
      skipped = []

      Array(params.setting_fields).each do |raw_field|
        field = raw_field.with_indifferent_access
        key = field["key"].presence
        next if key.blank?

        if existing_keys.include?(key)
          skipped << key
          next
        end

        new_field =
          workflow.setting_fields.create(
            key: key,
            label: field["label"].presence || key,
            description: field["description"],
            field_type: field["field_type"].presence || "string",
            type_options: field["type_options"].is_a?(Hash) ? field["type_options"] : {},
          )

        if new_field.persisted?
          created << new_field
          existing_keys << key
        else
          skipped << key
        end
      end

      { created:, skipped: }
    end

    def imported_any_fields(imported_fields:)
      imported_fields[:created].any?
    end

    def snapshot_workflow(workflow:, guardian:)
      workflow.snapshot!(user: guardian.user)
    end

    def index_dependencies(workflow:, workflow_version:)
      DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow, version: workflow_version)
    end

    def log_setting_fields_import(workflow:, imported_fields:, guardian:)
      return if imported_fields[:created].empty?

      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_setting_fields_imported",
        subject: workflow.name,
        created_count: imported_fields[:created].size,
        skipped_count: imported_fields[:skipped].size,
      )
    end
  end
end
