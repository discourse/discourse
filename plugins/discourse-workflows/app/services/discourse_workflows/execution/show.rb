# frozen_string_literal: true

module DiscourseWorkflows
  class Execution::Show
    include Service::Base

    params { attribute :execution_id, :integer }

    model :execution

    private

    def fetch_execution(params:)
      DiscourseWorkflows::Execution.includes(steps: :node).find_by(id: params.execution_id)
    end
  end
end
