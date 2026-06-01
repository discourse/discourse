# frozen_string_literal: true

module DiscourseWorkflows
  class FormTestSessionsController < ::Admin::AdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    def create
      DiscourseWorkflows::FormTestSession::Create.call(
        service_params.deep_merge(
          params: {
            workflow_id: params[:id],
            trigger_node_id: params[:trigger_node_id],
          },
        ),
      ) do |result|
        on_success do |token:|
          render json: { test_url: "/workflows/form-test/#{token}" }, status: :created
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failed_policy(:form_trigger_node) { raise Discourse::NotFound }
        on_model_not_found(:workflow) { raise Discourse::NotFound }
        on_model_not_found(:trigger_node) { raise Discourse::NotFound }
      end
    end
  end
end
