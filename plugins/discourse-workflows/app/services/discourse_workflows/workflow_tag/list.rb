# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowTag::List
    include Service::Base

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows

    model :workflow_tags, optional: true

    private

    def fetch_workflow_tags
      DiscourseWorkflows::WorkflowTag
        .joins(
          "LEFT JOIN discourse_workflows_workflow_tags wtm ON wtm.workflow_tag_id = discourse_workflows_tags.id",
        )
        .select("discourse_workflows_tags.*", "COUNT(wtm.id) AS workflow_count_value")
        .group("discourse_workflows_tags.id")
        .order(:name)
        .to_a
    end
  end
end
