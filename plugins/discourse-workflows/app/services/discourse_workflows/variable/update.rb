# frozen_string_literal: true

module DiscourseWorkflows
  class Variable::Update
    include Service::Base

    params do
      attribute :variable_id, :integer
      attribute :key, :string
      attribute :value, :string
      attribute :description, :string

      validates :key, presence: true
      validates :value, presence: true
    end

    policy :can_manage_workflows
    model :variable

    transaction do
      model :variable, :save_variable
      step :log_variable_update
    end

    private

    def can_manage_workflows(guardian:)
      guardian.is_admin?
    end

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
