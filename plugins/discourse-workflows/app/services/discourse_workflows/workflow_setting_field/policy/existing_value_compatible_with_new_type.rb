# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowSettingField::Policy::ExistingValueCompatibleWithNewType < Service::PolicyBase
    delegate :workflow_setting_field, :params, to: :context, private: true

    def call
      DiscourseWorkflows::WorkflowSettingField.value_valid_for_type?(
        value: workflow_setting_field.value,
        field_type: params.field_type,
        type_options: params.type_options,
      )
    end

    def reason
      I18n.t("discourse_workflows.errors.setting_field.incompatible_value_for_new_type")
    end
  end
end
