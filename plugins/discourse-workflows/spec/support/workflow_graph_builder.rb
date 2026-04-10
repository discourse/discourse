# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowGraphBuilder
    def initialize
      @nodes = []
      @connections = []
      @position_counter = 0
    end

    def node(id, type, name: nil, configuration: {})
      @nodes << {
        "id" => id,
        "type" => type,
        "type_version" => "1.0",
        "name" => name || type.split(":").last.humanize,
        "position_index" => @position_counter,
        "configuration" => configuration,
      }
      @position_counter += 1
      self
    end

    def connect(source, target, output: "main")
      @connections << {
        "source_node_id" => source,
        "target_node_id" => target,
        "source_output" => output,
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
  end
end

def build_workflow_graph
  builder = DiscourseWorkflows::WorkflowGraphBuilder.new
  yield builder
  builder.to_h
end
