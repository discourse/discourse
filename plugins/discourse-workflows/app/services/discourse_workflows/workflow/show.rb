# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::Show
    include Service::Base

    params { attribute :workflow_id, :integer }

    model :workflow

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::Workflow.includes(:nodes, :connections, :created_by).find_by(
        id: params.workflow_id,
      )
    end
  end
end
