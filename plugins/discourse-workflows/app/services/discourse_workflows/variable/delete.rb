# frozen_string_literal: true

module DiscourseWorkflows
  class Variable::Delete
    include Service::Base

    params { attribute :variable_id, :integer }

    model :variable
    step :log
    step :delete_variable

    private

    def fetch_variable(params:)
      DiscourseWorkflows::Variable.find_by(id: params.variable_id)
    end

    def log(variable:, guardian:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_variable_destroyed",
        subject: variable.key,
      )
    end

    def delete_variable(variable:)
      variable.destroy!
    end
  end
end
