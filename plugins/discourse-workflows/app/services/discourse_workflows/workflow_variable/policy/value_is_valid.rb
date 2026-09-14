# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowVariable::Policy::ValueIsValid < Service::PolicyBase
    delegate :variable, :params, to: :context, private: true

    def call
      DiscourseWorkflows::Variable.value_valid_for_type?(
        value: params.value,
        variable_type: variable.variable_type,
        type_options: variable.type_options,
      )
    end

    def reason
      I18n.t("discourse_workflows.errors.workflow_variable.invalid_value")
    end
  end
end
