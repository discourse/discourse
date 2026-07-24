# frozen_string_literal: true

module DiscourseWorkflows
  class Variable::Update
    include Service::Base

    params do
      attribute :variable_id, :integer
      attribute :key, :string
      attribute :value, :string
      attribute :description, :string

      validates :variable_id, presence: true
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

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    model :variable

    model :variable, :save_variable
    step :log_variable_update

    private

    def fetch_variable(params:)
      DiscourseWorkflows::Variable.find_by(id: params.variable_id)
    end

    def save_variable(variable:, params:)
      variable.tap { |v| v.update(**params.slice(:key, :value, :description)) }
    end

    def log_variable_update(variable:, guardian:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_variable_updated",
        subject: variable.key,
      )
    end
  end
end
