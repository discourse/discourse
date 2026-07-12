# frozen_string_literal: true

module DiscourseWorkflows
  class TopicSuperAdminButtonController < ::ApplicationController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    before_action :ensure_logged_in

    def create
      DiscourseWorkflows::Workflow::TriggerTopicAdminButton.call(service_params) do
        on_success { head :no_content }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_model_not_found(:published_trigger) { raise Discourse::NotFound }
        on_model_not_found(:topic) { raise Discourse::NotFound }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
      end
    end
  end
end
