# frozen_string_literal: true

module DiscourseWorkflows
  class Execution::Destroy
    include Service::Base

    params do
      attribute :ids, :array
      validates :ids, presence: true
    end

    step :delete_executions

    private

    def delete_executions(params:)
      context[:deleted_count] = DiscourseWorkflows::Execution.where(id: params.ids).delete_all
    end
  end
end
