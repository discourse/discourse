# frozen_string_literal: true

module DiscourseWorkflows
  class Variable::Create
    include Service::Base

    params do
      attribute :key, :string
      attribute :value, :string
      attribute :description, :string

      validates :key, presence: true
      validates :value, presence: true
    end

    model :variable, :create_variable
    step :log

    private

    def create_variable(params:)
      DiscourseWorkflows::Variable.create(
        key: params.key,
        value: params.value,
        description: params.description,
      )
    end

    def log(variable:, guardian:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_variable_created",
        subject: variable.key,
      )
    end
  end
end
