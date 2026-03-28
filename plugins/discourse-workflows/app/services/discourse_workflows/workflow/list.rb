# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::List
    include Service::Base

    DEFAULT_LIMIT = 25
    MAX_LIMIT = 100

    LATEST_EXECUTION_JOIN = <<~SQL.freeze
      LEFT JOIN LATERAL (
        SELECT status, discourse_workflows_executions.created_at AS executed_at
        FROM discourse_workflows_executions
        WHERE discourse_workflows_executions.workflow_id = discourse_workflows_workflows.id
        ORDER BY discourse_workflows_executions.created_at DESC, discourse_workflows_executions.id DESC
        LIMIT 1
      ) latest_execution ON TRUE
    SQL

    params do
      attribute :cursor, :integer
      attribute :limit, :integer

      before_validation { self.limit = [[limit.to_i, 1].max, MAX_LIMIT].min if limit.present? }
    end

    model :workflows, optional: true
    step :compute_pagination

    private

    def fetch_workflows(params:)
      limit = params.limit || DEFAULT_LIMIT

      scope =
        DiscourseWorkflows::Workflow
          .includes(:nodes, :connections, :created_by, :updated_by)
          .joins(LATEST_EXECUTION_JOIN)
          .select(
            "discourse_workflows_workflows.*",
            "latest_execution.status AS last_execution_status_value",
            "latest_execution.executed_at AS last_execution_at",
          )
          .order(id: :desc)

      scope = scope.where("discourse_workflows_workflows.id < ?", params.cursor) if params.cursor

      scope.limit(limit + 1)
    end

    def compute_pagination(workflows:, params:)
      limit = params.limit || DEFAULT_LIMIT
      has_more = workflows.size > limit

      context[:workflows] = has_more ? workflows.first(limit) : workflows
      context[:total_rows] = DiscourseWorkflows::Workflow.count
      context[:load_more_url] = if has_more
        "/admin/plugins/discourse-workflows/workflows.json?cursor=#{context[:workflows].last.id}&limit=#{limit}"
      end
    end
  end
end
