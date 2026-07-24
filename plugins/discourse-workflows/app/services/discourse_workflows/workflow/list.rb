# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::List
    include Service::Base

    LATEST_EXECUTION_JOIN = <<~SQL
      LEFT JOIN LATERAL (
        SELECT status, discourse_workflows_executions.created_at AS executed_at
        FROM discourse_workflows_executions
        WHERE discourse_workflows_executions.workflow_id = discourse_workflows_workflows.id
        ORDER BY discourse_workflows_executions.created_at DESC, discourse_workflows_executions.id DESC
        LIMIT 1
      ) latest_execution ON TRUE
    SQL

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows

    params do
      attribute :cursor, :integer
      attribute :limit, :integer
      attribute :filter, :string
      attribute :trigger_type, :string
      attribute :exclude_id, :integer

      after_validation do
        self.limit =
          (limit || DiscourseWorkflows::Pagination::DEFAULT_LIMIT).clamp(
            1,
            DiscourseWorkflows::Pagination::MAX_LIMIT,
          )
      end
    end

    model :workflows, optional: true
    model :has_more, :compute_has_more, optional: true
    model :total_rows, optional: true
    model :load_more_url, :build_load_more_url, optional: true

    private

    def fetch_workflows(params:)
      scope =
        DiscourseWorkflows::Workflow
          .filtered(
            name: params.filter,
            trigger_type: params.trigger_type,
            exclude_id: params.exclude_id,
          )
          .includes(:created_by, :updated_by, :error_workflow)
          .joins(LATEST_EXECUTION_JOIN)
          .select(
            "discourse_workflows_workflows.*",
            "latest_execution.status AS last_execution_status_value",
            "latest_execution.executed_at AS last_execution_at",
          )
          .order(id: :desc)

      scope = scope.where("discourse_workflows_workflows.id < ?", params.cursor) if params.cursor

      scope.limit(params.limit + 1).to_a
    end

    def compute_has_more(workflows:, params:)
      has_more = workflows.size > params.limit
      workflows.pop if has_more
      context[:has_more] = has_more
      has_more
    end

    def has_more
      context[:has_more]
    end

    def fetch_total_rows(params:)
      DiscourseWorkflows::Workflow.filtered(
        name: params.filter,
        trigger_type: params.trigger_type,
        exclude_id: params.exclude_id,
      ).count
    end

    def build_load_more_url(params:, workflows:)
      return if !has_more || workflows.blank?

      query = {
        cursor: workflows.last.id,
        limit: params.limit,
        filter: params.filter.presence,
        trigger_type: params.trigger_type.presence,
        exclude_id: params.exclude_id,
      }.compact

      "/admin/plugins/discourse-workflows/workflows.json?#{query.to_query}"
    end
  end
end
