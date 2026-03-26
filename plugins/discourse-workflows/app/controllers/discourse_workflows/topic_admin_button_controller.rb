# frozen_string_literal: true

module DiscourseWorkflows
  class TopicAdminButtonController < ::ApplicationController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    before_action :ensure_logged_in

    def create
      DiscourseWorkflows::Workflow::TriggerTopicAdminButton.call(
        service_params.deep_merge(
          params: {
            trigger_node_id: params[:trigger_node_id],
            topic_id: params[:topic_id],
          },
        ),
      ) do
        on_success { head :no_content }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_model_not_found(:trigger_node) { raise Discourse::NotFound }
        on_model_not_found(:topic) { raise Discourse::NotFound }
        on_failed_policy(:allowed_user) { raise Discourse::InvalidAccess }
      end
    end
  end
end
