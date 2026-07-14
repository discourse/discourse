# frozen_string_literal: true

module DiscourseWorkflows
  class Variable::Create
    include Service::Base

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows

    params do
      attribute :key, :string
      attribute :value, :string
      attribute :description, :string

      validates :key,
                presence: true,
                length: {
                  maximum: 100,
                },
                format: {
                  with: /\A[a-zA-Z_][a-zA-Z0-9_]*\z/,
                }
      validates :value, presence: true, length: { maximum: 1000 }
      validates :description, length: { maximum: 500 }, allow_nil: true
    end

    model :variable, :create_variable
    step :log_variable_creation

    private

    def create_variable(params:, guardian:)
      DiscourseWorkflows::Variable.create(**params, created_by: guardian.user)
    end

    def log_variable_creation(variable:, guardian:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_variable_created",
        subject: variable.key,
      )
    end
  end
end
