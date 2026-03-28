# frozen_string_literal: true

module DiscourseWorkflows
  class Execution::List
    include Service::Base

    DEFAULT_LIMIT = 25
    MAX_LIMIT = 100

    params do
      attribute :workflow_id, :integer
      attribute :cursor, :integer
      attribute :limit, :integer

      before_validation do
        self.limit = [[limit.to_i, 1].max, Execution::List::MAX_LIMIT].min if limit.present?
      end
    end

    model :executions, optional: true
    step :compute_total_rows
    step :compute_load_more_url

    private

    def fetch_executions(params:)
      limit = params.limit || DEFAULT_LIMIT

      scope = DiscourseWorkflows::Execution.order(id: :desc).includes(:workflow, steps: :node)
      scope = scope.where(workflow_id: params.workflow_id) if params.workflow_id
      scope = scope.where("discourse_workflows_executions.id < ?", params.cursor) if params.cursor

      results = scope.limit(limit + 1).to_a
      context[:has_more] = results.size > limit

      context[:has_more] ? results.first(limit) : results
    end

    def compute_total_rows(params:)
      scope = DiscourseWorkflows::Execution
      scope = scope.where(workflow_id: params.workflow_id) if params.workflow_id
      context[:total_rows] = scope.count
    end

    def compute_load_more_url(params:, executions:)
      limit = params.limit || DEFAULT_LIMIT
      context[:load_more_url] = if context[:has_more] && executions.present?
        base =
          if params.workflow_id
            "/admin/plugins/discourse-workflows/workflows/#{params.workflow_id}/executions.json"
          else
            "/admin/plugins/discourse-workflows/executions.json"
          end
        "#{base}?cursor=#{executions.last.id}&limit=#{limit}"
      end
    end
  end
end
