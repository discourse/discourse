# frozen_string_literal: true

module DiscourseWorkflows
  class DynamicNodeParametersController < ::SuperAdmin::SuperAdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    def options
      node_type = hash_param(:nodeTypeAndVersion)
      identifier = node_type["name"].presence
      raise Discourse::NotFound if identifier.blank?

      version = node_type["version"].presence&.to_s
      node_class = DiscourseWorkflows::Registry.find_node_type(identifier, version: version)
      raise Discourse::NotFound unless node_class.respond_to?(:load_options_context)

      context =
        DiscourseWorkflows::LoadOptionsContext.new(
          method_name: params[:methodName],
          property_name: params[:path],
          node_identifier: identifier,
          node_version: version,
          node_id: hash_param(:node).dig("id"),
          node_name: hash_param(:node).dig("name"),
          workflow_id: params[:workflowId],
          parameters: hash_param(:currentNodeParameters),
          credentials: hash_param(:credentials),
          filter: params[:filter],
          input_context: hash_param(:inputContext),
          execution_context: hash_param(:executionContext),
          user: current_user,
          guardian: guardian,
          node_class: node_class,
        )

      options = node_class.load_options_context(context)
      raise Discourse::NotFound if options.nil?

      render_json_dump options
    end

    private

    def hash_param(key)
      value = params[key]
      value = JSON.parse(value) if value.is_a?(String) && value.start_with?("{")
      value = value.to_unsafe_h if value.respond_to?(:to_unsafe_h)
      value.is_a?(Hash) ? value : {}
    end
  end
end
