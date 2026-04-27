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

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows

    params do
      attribute :cursor, :integer
      attribute :limit, :integer
      attribute :filter, :string
      attribute :trigger_type, :string
      attribute :exclude_id, :integer

      after_validation { self.limit = (limit || DEFAULT_LIMIT).clamp(1, MAX_LIMIT) }
    end

    model :workflows, optional: true
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

      results = scope.limit(params.limit + 1).to_a
      context[:has_more] = results.size > params.limit

      context[:has_more] ? results.first(params.limit) : results
    end

    def fetch_total_rows(params:)
      DiscourseWorkflows::Workflow.filtered(
        name: params.filter,
        trigger_type: params.trigger_type,
        exclude_id: params.exclude_id,
      ).count
    end

    def build_load_more_url(params:, workflows:)
      return unless context[:has_more] && workflows.present?

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
