# frozen_string_literal: true

module DiscourseWorkflows
  class NodeTypesController < ::Admin::AdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    def index
      DiscourseWorkflows::NodeType::List.call(service_params) do |result|
        on_success do |node_types:, credential_types:|
          render json: { node_types: node_types, credential_types: credential_types }
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end
  end
end
