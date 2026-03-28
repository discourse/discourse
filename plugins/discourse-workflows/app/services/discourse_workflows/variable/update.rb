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

    model :variable
    policy :can_manage_workflows

    transaction do
      step :update_variable
      step :log_variable_update
    end

    private

    def fetch_variable(params:)
      DiscourseWorkflows::Variable.find_by(id: params.variable_id)
    end

    def can_manage_workflows(guardian:)
      guardian.is_admin?
    end

    def update_variable(variable:, params:)
      variable.update!(**params.slice(:key, :value, :description))
    end

    def log_variable_update(variable:, guardian:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_variable_updated",
        subject: variable.key,
      )
    end
  end
end
