# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowExecutionsController < ::Admin::AdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    def index
      DiscourseWorkflows::Execution::List.call(
        service_params.deep_merge(params: { workflow_id: params[:workflow_id] }),
      ) do |result|
        on_success do |executions:, total_rows:, load_more_url: nil|
          render json: {
                   executions:
                     serialize_data(executions, DiscourseWorkflows::ExecutionListSerializer),
                   meta: {
                     total_rows_executions: total_rows,
                     load_more_executions: load_more_url,
                   }.compact,
                 }
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
      end
    end
  end
end
