# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::Action::BuildExpressionPreviewContext < Service::ActionBase
    option :workflow, optional: true
    option :node_id, optional: true

    def call
      return default_context unless workflow
      context = default_context
      context["__execution"] = initial_execution_metadata
      populate_schema_exemplars(context)
      overlay_last_execution(context)
      context
    end

    private

    def default_context
      { "$json" => {}, "trigger" => {} }
    end

    def initial_execution_metadata
      { "id" => 0, "workflow_id" => workflow.id, "workflow_name" => workflow.name }
    end

    def populate_schema_exemplars(context)
      workflow.parsed_nodes.each { |node| apply_node_exemplar(context, node) }
      apply_upstream_exemplar(context) if node_id
    end

    def apply_node_exemplar(context, node)
      node_class = Registry.find_node_type(node["type"])
      return unless node_class

      json = node_class.output_exemplar

      if node["type"]&.start_with?("trigger:")
        context["trigger"] = json
        context["$json"] = json unless node_id
      end

      context[node["name"]] = [{ "json" => json }] if node["name"].present?
    end

    def apply_upstream_exemplar(context)
      upstream = workflow.upstream_node_of(node_id)
      return unless upstream
      node_class = Registry.find_node_type(upstream["type"])
      return unless node_class
      context["$json"] = node_class.output_exemplar
    end

    def overlay_last_execution(context)
      execution = workflow.last_successful_execution
      return unless execution
      context["__execution"]["id"] = execution.id
      return unless execution.execution_data
      overlay_execution_entries(context, execution.execution_data.entries)
    end

    def overlay_execution_entries(context, entries)
      upstream_name = node_id ? workflow.upstream_node_of(node_id)&.dig("name") : nil
      entries.each { |node_name, steps| apply_entry(context, node_name, steps, upstream_name) }
    end

    def apply_entry(context, node_name, steps, upstream_name)
      step = Array(steps).find { |s| s["status"] == "success" }
      return unless step

      items = step["output_items"] || step["items"] || []
      json = items.dig(0, "json") || {}

      if step["node_type"]&.start_with?("trigger:")
        context["trigger"] = json
        context["$json"] = json unless node_id
      end

      context[node_name] = [{ "json" => json }]
      context["$json"] = json if upstream_name && node_name == upstream_name
    end
  end
end
