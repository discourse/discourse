# frozen_string_literal: true

module DiscourseWorkflows
  class ExpressionsController < ::Admin::AdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    def evaluate
      RateLimiter.new(
        current_user,
        "expression-evaluate",
        30,
        60,
        apply_limit_to_staff: true,
      ).performed!

      template = params.require(:template)
      workflow_id = params[:workflow_id]
      node_id = params[:node_id]

      context = build_context(workflow_id, node_id)
      resolver = ExpressionResolver.new(context, user: current_user)

      segments = resolver.resolve_segments(template)

      render json: { segments: }
    rescue MiniRacer::Error => e
      Rails.logger.warn("Expression evaluation failed: #{e.message}")
      render json: { segments: [] }
    ensure
      resolver&.dispose
    end

    private

    def build_context(workflow_id, node_id)
      context = { "$json" => {}, "trigger" => {} }

      if workflow_id.present?
        workflow = Workflow.find_by(id: workflow_id)
        if workflow
          context["__execution"] = {
            "id" => 0,
            "workflow_id" => workflow.id,
            "workflow_name" => workflow.name,
          }

          populate_context_from_schema(context, workflow, node_id)

          execution =
            workflow
              .executions
              .includes(:execution_data)
              .where(status: :success)
              .order(created_at: :desc)
              .first

          if execution
            context["__execution"]["id"] = execution.id

            if execution.execution_data
              overlay_execution_data(context, execution.execution_data.entries, workflow, node_id)
            end
          end
        end
      end

      context
    end

    def populate_context_from_schema(context, workflow, node_id)
      nodes = workflow.parsed_nodes
      connections = workflow.parsed_connections

      nodes.each do |node|
        node_class = Registry.find_node_type(node["type"])
        next unless node_class.respond_to?(:output_schema)

        json = exemplar_from_schema(node_class.output_schema)

        if node["type"]&.start_with?("trigger:")
          context["trigger"] = json
          context["$json"] = json unless node_id
        end

        context[node["name"]] = [{ "json" => json }] if node["name"].present?
      end

      if node_id
        upstream = find_upstream_node(node_id, nodes, connections)
        if upstream
          node_class = Registry.find_node_type(upstream["type"])
          if node_class.respond_to?(:output_schema)
            context["$json"] = exemplar_from_schema(node_class.output_schema)
          end
        end
      end
    end

    def find_upstream_node(node_id, nodes, connections)
      conn = connections.find { |c| c["target_node_id"] == node_id.to_s }
      return unless conn
      nodes.find { |n| n["id"] == conn["source_node_id"] }
    end

    TYPE_EXEMPLARS = {
      string: "",
      integer: 0,
      number: 0,
      boolean: false,
      array: [],
      object: {
      },
    }.freeze

    def exemplar_from_schema(schema)
      schema.each_with_object({}) do |(key, value), hash|
        hash[key.to_s] = if value.is_a?(Hash)
          exemplar_from_schema(value)
        else
          TYPE_EXEMPLARS.fetch(value, "")
        end
      end
    end

    def overlay_execution_data(context, run_data, workflow, node_id)
      upstream_name = nil
      if node_id
        upstream = find_upstream_node(node_id, workflow.parsed_nodes, workflow.parsed_connections)
        upstream_name = upstream["name"] if upstream
      end

      run_data.each do |node_name, steps|
        step = Array(steps).find { |s| s["status"] == "success" }
        next unless step

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
end
