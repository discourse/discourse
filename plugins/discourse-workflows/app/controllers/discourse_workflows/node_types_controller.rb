# frozen_string_literal: true

module DiscourseWorkflows
  class NodeTypesController < ::SuperAdmin::SuperAdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    def index
      DiscourseWorkflows::NodeType::List.call(service_params) do |result|
        on_success do |node_types:, credential_types:, expression_context:|
          render json: {
                   node_types: node_types,
                   credential_types: credential_types,
                   expression_context: expression_context,
                 }
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
      end
    end
  end
end
