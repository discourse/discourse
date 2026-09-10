# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowSettingField::Policy::ValueIsValid < Service::PolicyBase
    delegate :workflow_setting_field, :params, to: :context, private: true

    def call
      DiscourseWorkflows::WorkflowSettingField.value_valid_for_type?(
        value: params.value,
        field_type: workflow_setting_field.field_type,
        type_options: workflow_setting_field.type_options,
      )
    end

    def reason
      I18n.t("discourse_workflows.errors.setting_field.invalid_value")
    end
  end
end
