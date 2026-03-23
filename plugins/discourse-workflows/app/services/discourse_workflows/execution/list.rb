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

      before_validation { self.limit = [[limit.to_i, 1].max, MAX_LIMIT].min if limit.present? }
    end

    step :list

    private

    def list(params:)
      limit = params.limit || DEFAULT_LIMIT

      scope = DiscourseWorkflows::Execution.order(id: :desc).includes(:workflow, steps: :node)
      scope = scope.where(workflow_id: params.workflow_id) if params.workflow_id
      scope = scope.where("discourse_workflows_executions.id < ?", params.cursor) if params.cursor

      results = scope.limit(limit + 1).to_a
      has_more = results.size > limit
      context[:executions] = has_more ? results.first(limit) : results

      count_scope = DiscourseWorkflows::Execution
      count_scope = count_scope.where(workflow_id: params.workflow_id) if params.workflow_id
      context[:total_rows] = count_scope.count

      context[:load_more_url] = if has_more
        base =
          if params.workflow_id
            "/admin/plugins/discourse-workflows/workflows/#{params.workflow_id}/executions.json"
          else
            "/admin/plugins/discourse-workflows/executions.json"
          end
        "#{base}?cursor=#{context[:executions].last.id}&limit=#{limit}"
      end
    end
  end
end
