# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowGraphBuilder
    def initialize
      @nodes = []
      @connections = {}
      @position_counter = 0
    end

    def node(
      id,
      type,
      name: nil,
      parameters: nil,
      credentials: {},
      webhook_id: nil,
      position: nil,
      configuration: {}
    )
      configuration = configuration.deep_stringify_keys
      webhook_id ||=
        configuration.delete("uuid") if DiscourseWorkflows::NodeDataShape.form_trigger?(type)
      node_level_settings = DiscourseWorkflows::NodeData.direct_settings(configuration)
      direct_setting_keys = DiscourseWorkflows::NodeData::NODE_DIRECT_SETTING_KEYS.keys
      parameters ||= configuration.except(*direct_setting_keys)
      split =
        DiscourseWorkflows::NodeData.split(
          parameters: parameters,
          credentials: credentials,
          webhook_id: webhook_id,
          node_type: registered_node_type(type) || type,
        )

      node = {
        "id" => id,
        "type" => type,
        "typeVersion" => "1.0",
        "name" => name || id.to_s.humanize,
        "position" => position || { "x" => @position_counter * 220, "y" => 0 },
        "parameters" => split["parameters"],
        "credentials" => split["credentials"],
        "webhookId" => split["webhookId"],
      }

      @nodes << node.merge(node_level_settings)
      @position_counter += 1
      self
    end

    def connect(source, target, output: "main", input: "main")
      source_node = @nodes.find { |node| node["id"] == source }
      target_node = @nodes.find { |node| node["id"] == target }
      return self if source_node.blank? || target_node.blank?

      source_name = source_node["name"]
      @connections[source_name] ||= {}
      @connections[source_name]["main"] ||= []
      source_output_index = connection_index(output)
      while @connections[source_name]["main"].length <= source_output_index
        @connections[source_name]["main"] << []
      end
      @connections[source_name]["main"][source_output_index] << {
        "node" => target_node["name"],
        "type" => "main",
        "index" => connection_index(input),
      }
      self
    end

    def chain(*node_ids, output: "main")
      node_ids.each_cons(2) { |source, target| connect(source, target, output: output) }
      self
    end

    def to_h
      { nodes: @nodes, connections: @connections }
    end

    private

    def registered_node_type(type)
      DiscourseWorkflows::NodeType.registered_nodes.find { _1.description[:name] == type }
    end

    def connection_index(value)
      value = value.to_s
      return 0 if value.blank? || value == "main" || value == "true" || value == "done"

      match = value.match(/\Ainput_(\d+)\z/)
      return match[1].to_i - 1 if match

      return 1 if %w[false loop].include?(value)

      value.to_i
    end
  end
end

def build_workflow_graph
  builder = DiscourseWorkflows::WorkflowGraphBuilder.new
  yield builder
  builder.to_h
end

def workflow_connections_for(nodes, *edges)
  nodes_by_id = nodes.index_by { |node| node["id"].to_s }

  edges.each_with_object({}) do |edge, connections|
    source_id, target_id, source_output_index, target_input_index = edge
    source_node = nodes_by_id[source_id.to_s]
    target_node = nodes_by_id[target_id.to_s]
    next if source_node.blank? || target_node.blank?

    connections[source_node["name"]] ||= {}
    connections[source_node["name"]]["main"] ||= []
    source_output_index = source_output_index.to_i
    while connections[source_node["name"]]["main"].length <= source_output_index
      connections[source_node["name"]]["main"] << []
    end
    connections[source_node["name"]]["main"][source_output_index] << {
      "node" => target_node["name"],
      "type" => "main",
      "index" => target_input_index.to_i,
    }
  end
end

def workflow_nodes_with_update(workflow, node_id)
  workflow.nodes.map do |workflow_node|
    node = workflow_node.deep_dup
    next node unless node["id"] == node_id

    updated_node = yield node
    updated_node.is_a?(Hash) ? updated_node : node
  end
end

def update_workflow_node(workflow, node_id, &block)
  workflow.update!(nodes: workflow_nodes_with_update(workflow, node_id, &block))
end

def publish_workflow!(workflow)
  version = workflow.snapshot!(user: workflow.created_by)
  workflow.update!(active_version_id: workflow.version_id)
  DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow, version:)
  DiscourseWorkflows::Webhook::Action::ActivateWebhooks.call(
    workflow: workflow,
    workflow_version: version,
  )
  workflow.reload
end

def unpublish_workflow!(workflow)
  workflow.update!(active_version_id: nil)
  DiscourseWorkflows::Webhook::Action::DeactivateWebhooks.call(workflow: workflow)
end
