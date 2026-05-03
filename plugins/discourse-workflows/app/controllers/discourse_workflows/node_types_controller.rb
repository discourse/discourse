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

    def options
      node_class = DiscourseWorkflows::Registry.find_node_type(params[:identifier])
      raise Discourse::NotFound unless node_class.respond_to?(:load_options)

      options = node_class.load_options(params[:source_key])
      raise Discourse::NotFound if options.nil?

      render json: { options: options }
    end
  end
end
