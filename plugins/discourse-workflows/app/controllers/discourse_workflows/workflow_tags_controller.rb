# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowTagsController < ::Admin::AdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    def index
      DiscourseWorkflows::WorkflowTag::List.call(service_params) do |result|
        on_success do |workflow_tags:|
          render json: {
                   workflow_tags:
                     serialize_data(workflow_tags, DiscourseWorkflows::WorkflowTagSerializer),
                 }
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
      end
    end
  end
end
