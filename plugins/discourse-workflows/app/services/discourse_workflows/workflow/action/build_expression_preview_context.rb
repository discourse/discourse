# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::Action::BuildExpressionPreviewContext < Service::ActionBase
    option :workflow, optional: true
    option :node_id, optional: true

    def call
      return default_context unless workflow
      context = default_context
      context["__execution"] = initial_execution_metadata
      context["__current_node_id"] = node_id.to_s if node_id.present?
      context["__node_parameters_by_name"] = node_parameters_by_name
      overlay_last_execution(context)
      context
    end

    private

    def default_context
      { "$json" => {}, "$trigger" => {} }
    end

    def initial_execution_metadata
      { "id" => 0, "workflow_id" => workflow.id, "workflow_name" => workflow.name }
    end

    def overlay_last_execution(context)
      execution = workflow.last_successful_execution
      return unless execution
      context["__execution"]["id"] = execution.id
      return unless execution.execution_data

      node_runs = node_runs_for_expression(execution.execution_data.run_data)
      context["__node_runs"] = node_runs
      overlay_execution_run_data(context, node_runs)
    end

    def overlay_execution_run_data(context, node_runs)
      upstream_connections = upstream_connections_for(node_id)
      primary_upstream_connection = upstream_connections.first
      current_input = current_node_input(node_runs, primary_upstream_connection)

      workflow.nodes.each do |node|
        next if node["name"].blank?
        runs = Array(node_runs[node["name"]])
        run = runs.last
        next unless run

        output_index = primary_output_index_for(node, primary_upstream_connection)
        items = Array(run.dig("outputs", output_index))
        first_json = items.dig(0, "json") || {}

        if node["type"]&.start_with?("trigger:")
          context["$trigger"] = first_json
          context["$json"] = first_json unless node_id
        end

        context[node["name"]] = items
      end

      overlay_current_input(context, current_input) if current_input
    end

    def primary_output_index_for(node, primary_upstream_connection)
      if primary_upstream_connection&.source_node_id.to_s == node["id"].to_s
        return primary_upstream_connection.source_output_index.to_i
      end

      0
    end

    def current_node_input(node_runs, primary_upstream_connection)
      return if node_id.blank?

      current_node = workflow.find_node(node_id)
      return if current_node.nil? || current_node["name"].blank?

      run = Array(node_runs[current_node["name"]]).last
      return input_from_connected_source(node_runs, primary_upstream_connection) unless run

      input_index = (primary_upstream_connection&.target_input_index || 0).to_i
      return unless input_source_matches_connection?(run, input_index, primary_upstream_connection)

      items = run.dig("inputs", input_index)
      return unless items

      { "items" => Array(items), "input_sources" => Array(run["input_sources"]) }
    end

    def input_from_connected_source(node_runs, connection)
      return unless connection

      source_node = workflow_snapshot.source_node(connection)
      return if source_node.blank? || source_node.name.blank?

      run = Array(node_runs[source_node.name]).last
      return unless run

      output_index = connection.source_output_index.to_i
      items = run.dig("outputs", output_index)
      return unless items

      {
        "items" => Array(items),
        "input_sources" => [{ "node_name" => source_node.name, "output_index" => output_index }],
      }
    end

    def overlay_current_input(context, current_input)
      items = current_input["items"]
      context["$json"] = items.dig(0, "json") || {}
      context["__input_item"] = items.first || { "json" => {} }
      context["__input_items"] = items
      if current_input["input_sources"].present?
        context["__input_sources"] = current_input["input_sources"]
      end
    end

    def upstream_connections_for(target_node_id)
      return [] if target_node_id.blank?

      target_node = workflow_snapshot.find_node(target_node_id)
      return [] unless target_node

      workflow_snapshot.connections_to(target_node)
    end

    def workflow_snapshot
      @workflow_snapshot ||=
        DiscourseWorkflows::WorkflowSnapshot.new(
          "name" => workflow.name,
          "nodes" => workflow.nodes,
          "connections" => workflow.connections,
        )
    end

    def node_runs_for_expression(run_data)
      run_data.each_with_object({}) do |(node_name, runs), result|
        node = workflow_node_by_name[node_name.to_s]
        next unless node

        matching_runs =
          Array(runs).filter_map do |run|
            next unless run["status"] == "success"
            next unless run_matches_node?(run, node)

            {
              "node_id" => run["node_id"],
              "node_type" => run["node_type"],
              "inputs" => ports_to_item_groups(run["inputs"]),
              "outputs" => ports_to_item_groups(run["outputs"]),
              "input_sources" => input_sources(run["inputs"]),
            }
          end
        result[node_name] = matching_runs if matching_runs.present?
      end
    end

    def workflow_node_by_name
      @workflow_node_by_name ||=
        workflow
          .nodes
          .each_with_object({}) do |node, by_name|
            name = node["name"].to_s
            next if name.blank?

            by_name[name] = by_name.key?(name) ? nil : node
          end
          .compact
    end

    def run_matches_node?(run, node)
      return false if run["node_id"].present? && run["node_id"].to_s != node["id"].to_s
      return false if run["node_type"].present? && run["node_type"].to_s != node["type"].to_s

      true
    end

    def input_source_matches_connection?(run, input_index, connection)
      return false unless connection

      source = Array(run["input_sources"])[input_index]
      source_node = workflow_snapshot.source_node(connection)
      return false if source.blank? || source_node.blank?

      source["node_name"].to_s == source_node.name.to_s &&
        source["output_index"].to_i == connection.source_output_index.to_i
    end

    def ports_to_item_groups(ports)
      Array(ports).map { |port| Array(port["items"]) }
    end

    def input_sources(input_ports)
      Array(input_ports).map { |port| port["source"] || {} }
    end

    def node_parameters_by_name
      workflow
        .nodes
        .each_with_object({}) do |node, by_name|
          name = node["name"].to_s
          next if name.blank?

          by_name[name] = by_name.key?(name) ? nil : node["parameters"] || {}
        end
        .compact
    end
  end
end
