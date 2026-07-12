# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowVersionsController < ::SuperAdmin::SuperAdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    def index
      DiscourseWorkflows::WorkflowVersion::List.call(service_params) do |result|
        on_success do |workflow:, versions:, total_rows:, load_more_url:|
          render json: {
                   versions:
                     serialize_data(
                       versions,
                       DiscourseWorkflows::WorkflowVersionSerializer,
                       current_version_id: workflow.version_id,
                       active_version_id: workflow.active_version_id,
                     ),
                   meta: { total_rows: total_rows, load_more_url: load_more_url }.compact,
                 }
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_model_not_found(:workflow) { raise Discourse::NotFound }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
      end
    end

    def restore
      DiscourseWorkflows::Workflow::RevertToVersion.call(service_params) do |result|
        on_success do |workflow:|
          render_serialized(workflow, DiscourseWorkflows::WorkflowSerializer, root: "workflow")
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_model_not_found(:workflow) { raise Discourse::NotFound }
        on_model_not_found(:version) { raise Discourse::NotFound }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_model_errors(:workflow) do |model|
          render(
            json: failed_json.merge(errors: model.errors.full_messages),
            status: :unprocessable_entity,
          )
        end
      end
    end
  end
end
