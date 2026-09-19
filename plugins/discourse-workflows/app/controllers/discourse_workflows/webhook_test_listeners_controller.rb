# frozen_string_literal: true

module DiscourseWorkflows
  class WebhookTestListenersController < ::Admin::AdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    def create
      DiscourseWorkflows::WebhookTestListener::Start.call(
        service_params.deep_merge(
          params: {
            workflow_id: params[:id],
            trigger_node_id: params[:trigger_node_id],
          },
        ),
      ) do |result|
        on_success do |listener:|
          render(
            json: {
              listener_id: listener.listener_id,
              test_url: listener.test_url,
              expires_at: listener.expires_at.iso8601,
            },
            status: :created,
          )
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failed_policy(:webhook_trigger_node) { raise Discourse::NotFound }
        on_model_not_found(:workflow) { raise Discourse::NotFound }
        on_model_not_found(:trigger_node) { raise Discourse::NotFound }
      end
    end

    def destroy
      DiscourseWorkflows::WebhookTestListener::Cancel.call(
        service_params.deep_merge(
          params: {
            workflow_id: params[:id],
            listener_id: params[:listener_id],
          },
        ),
      ) do
        on_success { head :no_content }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failed_policy(:listener_belongs_to_workflow) { raise Discourse::NotFound }
        on_failed_policy(:owns_webhook_test_listener) { raise Discourse::InvalidAccess }
        on_model_not_found(:workflow) { raise Discourse::NotFound }
        on_model_not_found(:listener) { raise Discourse::NotFound }
      end
    end
  end
end
