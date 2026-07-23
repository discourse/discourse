# frozen_string_literal: true

module DiscourseWorkflows
  class StepExecutionsController < ::Admin::AdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    def create
      DiscourseWorkflows::Workflow::ExecuteStep.call(service_params) do |result|
        on_success do |execution:|
          render json: {
                   execution: {
                     id: execution.id,
                     workflow_id: execution.workflow_id,
                   },
                 },
                 status: :created
        end
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failed_policy(:step_node_executable) { render_step_execution_error("not_executable") }
        on_failed_policy(:step_node_not_waiting) do
          render_step_execution_error("waiting_not_supported")
        end
        on_failed_policy(:step_data_reachable) { render_step_execution_error("missing_input_data") }
        on_failed_policy(:execution_path_not_waiting) do
          render_step_execution_error("waiting_not_supported")
        end
        on_model_not_found(:workflow) { raise Discourse::NotFound }
        on_model_not_found(:step_node) { raise Discourse::NotFound }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end

    private

    def render_step_execution_error(key)
      render json:
               failed_json.merge(
                 errors: [I18n.t("discourse_workflows.errors.step_execution.#{key}")],
               ),
             status: :unprocessable_entity
    end
  end
end
