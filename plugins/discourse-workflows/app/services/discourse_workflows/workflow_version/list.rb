# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowVersion::List
    include Service::Base

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows

    params do
      attribute :workflow_id, :integer
      attribute :cursor, :integer
      attribute :limit, :integer

      validates :workflow_id, presence: true

      after_validation { self.limit = DiscourseWorkflows::Pagination.normalize_limit(limit) }
    end

    model :workflow
    model :versions, optional: true
    model :total_rows, :count_total_rows
    model :load_more_url, :build_load_more_url, optional: true

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::Workflow.find_by(id: params.workflow_id)
    end

    def fetch_versions(workflow:, params:)
      scope = workflow.workflow_versions.includes(:created_by).order(version_number: :desc)

      context[:page] = DiscourseWorkflows::Pagination.cursor_page(
        scope: scope,
        cursor: params.cursor,
        limit: params.limit,
        path: "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/versions.json",
        column: :version_number,
      )
      context[:page].records
    end

    def count_total_rows
      context[:page].total_rows
    end

    def build_load_more_url
      context[:page].load_more_url
    end
  end
end
