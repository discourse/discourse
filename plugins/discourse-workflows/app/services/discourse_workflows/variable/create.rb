# frozen_string_literal: true

module DiscourseWorkflows
  class Variable::Create
    include Service::Base

    policy :can_manage_workflows

    params do
      attribute :key, :string
      attribute :value, :string
      attribute :description, :string

      validates :key, presence: true
      validates :value, presence: true
    end

    model :variable, :create_variable
    step :log_variable_creation

    private

    def can_manage_workflows(guardian:)
      guardian.is_admin?
    end

    def create_variable(params:)
      DiscourseWorkflows::Variable.create(**params)
    end

    def log_variable_creation(variable:, guardian:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_variable_created",
        subject: variable.key,
      )
    end
  end
end
