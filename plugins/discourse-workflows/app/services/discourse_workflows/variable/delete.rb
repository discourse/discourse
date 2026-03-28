# frozen_string_literal: true

module DiscourseWorkflows
  class Variable::Delete
    include Service::Base

    params { attribute :variable_id, :integer }

    model :variable
    policy :can_manage_workflows
    step :log_variable_deletion
    step :destroy_variable

    private

    def fetch_variable(params:)
      DiscourseWorkflows::Variable.find_by(id: params.variable_id)
    end

    def can_manage_workflows(guardian:)
      guardian.is_admin?
    end

    def log_variable_deletion(variable:, guardian:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_variable_destroyed",
        subject: variable.key,
      )
    end

    def destroy_variable(variable:)
      variable.destroy!
    end
  end
end
