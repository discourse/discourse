# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowExecutionsController < ::Admin::AdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    def index
      DiscourseWorkflows::Execution::List.call(
        service_params.deep_merge(params: { workflow_id: params[:workflow_id] }),
      ) do |result|
        on_success do |executions:, load_more_url:, total_rows:|
          render json: {
                   executions: serialize_data(executions, DiscourseWorkflows::ExecutionSerializer),
                   meta: {
                     total_rows_executions: total_rows,
                     load_more_executions: load_more_url,
                   }.compact,
                 }
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end
  end
end
