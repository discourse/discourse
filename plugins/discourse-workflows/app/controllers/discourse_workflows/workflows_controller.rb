# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowsController < ::Admin::AdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    def index
      DiscourseWorkflows::Workflow::List.call(service_params) do |result|
        on_success do |workflows:, load_more_url:, total_rows:|
          render json: {
                   workflows: serialize_data(workflows, DiscourseWorkflows::WorkflowSerializer),
                   meta: {
                     total_rows_workflows: total_rows,
                     load_more_workflows: load_more_url,
                   }.compact,
                 }
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end

    def show
      DiscourseWorkflows::Workflow::Show.call(
        service_params.deep_merge(params: { workflow_id: params[:id] }),
      ) do |result|
        on_success do |workflow:|
          render_serialized(workflow, DiscourseWorkflows::WorkflowSerializer, root: "workflow")
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_model_not_found(:workflow) { raise Discourse::NotFound }
      end
    end

    def create
      DiscourseWorkflows::Workflow::Create.call(
        service_params.deep_merge(params: workflow_params),
      ) do |result|
        on_success do |workflow:|
          render_serialized(
            workflow.reload,
            DiscourseWorkflows::WorkflowSerializer,
            root: "workflow",
          )
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_failed_step(:populate_graph) do |step_result|
          render(
            json: failed_json.merge(errors: Array(step_result.error)),
            status: :unprocessable_entity,
          )
        end
        on_model_errors(:workflow) do |model|
          render(
            json: failed_json.merge(errors: model.errors.full_messages),
            status: :unprocessable_entity,
          )
        end
      end
    end

    def update
      DiscourseWorkflows::Workflow::Update.call(
        service_params.deep_merge(params: workflow_params.merge(workflow_id: params[:id])),
      ) do |result|
        on_success do |workflow:|
          render_serialized(
            workflow.reload,
            DiscourseWorkflows::WorkflowSerializer,
            root: "workflow",
          )
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_failed_step(:populate_graph) do |step_result|
          render(
            json: failed_json.merge(errors: Array(step_result.error)),
            status: :unprocessable_entity,
          )
        end
        on_model_not_found(:workflow) { raise Discourse::NotFound }
        on_model_errors(:workflow) do |model|
          render(
            json: failed_json.merge(errors: model.errors.full_messages),
            status: :unprocessable_entity,
          )
        end
      end
    end

    def destroy
      DiscourseWorkflows::Workflow::Destroy.call(
        service_params.deep_merge(params: { workflow_id: params[:id] }),
      ) do |result|
        on_success { head :no_content }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_model_not_found(:workflow) { raise Discourse::NotFound }
      end
    end

    private

    def workflow_params
      value = params[:workflow].presence || {}
      value.respond_to?(:to_unsafe_h) ? value.to_unsafe_h : value.to_h
    end
  end
end
