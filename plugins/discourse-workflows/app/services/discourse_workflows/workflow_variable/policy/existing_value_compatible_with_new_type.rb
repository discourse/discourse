# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowVariable::Policy::ExistingValueCompatibleWithNewType < Service::PolicyBase
    delegate :variable, :params, to: :context, private: true

    def call
      DiscourseWorkflows::Variable.value_valid_for_type?(
        value: variable.value,
        variable_type: params.variable_type,
        type_options: params.type_options,
      )
    end

    def reason
      I18n.t("discourse_workflows.errors.workflow_variable.incompatible_value_for_new_type")
    end
  end
end
