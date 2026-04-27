# frozen_string_literal: true

module DiscourseWorkflows
  class Execution::List
    include Service::Base

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows

    params do
      attribute :workflow_id, :integer
      attribute :cursor, :integer
      attribute :limit, :integer

      before_validation do
        self.limit =
          limit.to_i.clamp(1, DiscourseWorkflows::Pagination::MAX_LIMIT) if limit.present?
      end

      def effective_limit
        limit || DiscourseWorkflows::Pagination::DEFAULT_LIMIT
      end
    end

    model :executions, optional: true
    model :total_rows, :compute_total_rows
    only_if(:has_more) { model :load_more_url, :compute_load_more_url, optional: true }

    private

    def fetch_executions(params:)
      scope =
        DiscourseWorkflows::Execution
          .for_workflow(params.workflow_id)
          .order(id: :desc)
          .includes(:workflow)
      scope = scope.where("discourse_workflows_executions.id < ?", params.cursor) if params.cursor

      results = scope.limit(params.effective_limit + 1).to_a
      context[:has_more] = results.size > params.effective_limit

      context[:has_more] ? results.first(params.effective_limit) : results
    end

    def has_more
      context[:has_more]
    end

    def compute_total_rows(params:)
      DiscourseWorkflows::Execution.for_workflow(params.workflow_id).count
    end

    def compute_load_more_url(params:, executions:)
      path =
        if params.workflow_id
          "/admin/plugins/discourse-workflows/workflows/#{params.workflow_id}/executions.json"
        else
          "/admin/plugins/discourse-workflows/executions.json"
        end

      "#{path}?cursor=#{executions.last.id}&limit=#{params.effective_limit}"
    end
  end
end
