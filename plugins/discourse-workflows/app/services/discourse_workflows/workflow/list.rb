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

    step :list

    private

    def list(params:)
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

      results = scope.limit(limit + 1).to_a
      has_more = results.size > limit
      context[:workflows] = has_more ? results.first(limit) : results
      context[:total_rows] = DiscourseWorkflows::Workflow.count
      context[:load_more_url] = if has_more
        "/admin/plugins/discourse-workflows/workflows.json?cursor=#{context[:workflows].last.id}&limit=#{limit}"
      end
    end
  end
end
