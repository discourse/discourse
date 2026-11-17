# frozen_string_literal: true

module DiscourseWorkflows
  class NodeTypesController < ::Admin::AdminController
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

    def upgrade
      DiscourseWorkflows::NodeType::Upgrade.call(service_params) do |result|
        on_success do |upgrade:|
          render json: {
                   nodes: upgrade.nodes,
                   upgrades: upgrade.upgrades.map(&:to_h),
                   skipped: upgrade.skipped,
                 }
        end
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end
  end
end
