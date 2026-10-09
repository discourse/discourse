# frozen_string_literal: true

module DiscourseWorkflows
  class ExecutionsController < ::Admin::AdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    def create
      DiscourseWorkflows::Workflow::ManualExecute.call(
        service_params.deep_merge(params: { user_id: current_user.id }),
      ) do |result|
        on_success do |execution:|
          render json: {
                   execution: {
                     id: execution.id,
                     workflow_id: execution.workflow_id,
                   },
                 },
                 status: :created
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_model_not_found(:trigger_node) { raise Discourse::NotFound }
        on_model_not_found(:workflow) { raise Discourse::NotFound }
      end
    end

    def index
      message_bus_last_id =
        MessageBus.last_id(DiscourseWorkflows::ExecutionProgressPublisher::EXECUTIONS_CHANNEL)

      DiscourseWorkflows::Execution::List.call(service_params) do |result|
        on_success do |executions:, load_more_url:|
          render json: {
                   executions:
                     serialize_data(executions, DiscourseWorkflows::ExecutionListSerializer),
                   meta: {
                     load_more_executions: load_more_url,
                     message_bus_last_id: message_bus_last_id,
                   }.compact,
                 }
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
      end
    end

    def destroy
      DiscourseWorkflows::Execution::Destroy.call(
        service_params.deep_merge(params: { execution_ids: params[:ids] }),
      ) do |result|
        on_success { head :no_content }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
      end
    end

    def show
      channel = DiscourseWorkflows::ExecutionProgressPublisher.execution_channel(params[:id])
      message_bus_last_id = MessageBus.last_id(channel)

      DiscourseWorkflows::Execution::Show.call(
        service_params.deep_merge(params: { execution_id: params[:id] }),
      ) do |result|
        on_success do |execution:|
          render json: {
                   execution:
                     serialize_data(
                       execution,
                       DiscourseWorkflows::ExecutionSerializer,
                       root: false,
                     ),
                   meta: {
                     message_bus_last_id: message_bus_last_id,
                   },
                 }
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_model_not_found(:execution) { raise Discourse::NotFound }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
      end
    end
  end
end
