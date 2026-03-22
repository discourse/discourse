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
    step :update_variable
    step :log

    private

    def fetch_variable(params:)
      DiscourseWorkflows::Variable.find_by(id: params.variable_id)
    end

    def update_variable(variable:, params:)
      variable.update!(key: params.key, value: params.value, description: params.description)
    end

    def log(variable:, guardian:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_variable_updated",
        subject: variable.key,
      )
    end
  end
end
