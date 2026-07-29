# frozen_string_literal: true

module DiscourseWorkflows
  class StepExecutionPlanBuilder
    def snapshot(graph:, pin_data: {})
      WorkflowSnapshot.new(
        "name" => "Test workflow",
        "nodes" => graph[:nodes],
        "connections" => graph[:connections],
        "pinData" => pin_data,
      )
    end

    def plan(snapshot:, node_id:, run_data: {})
      StepExecutionPlan.new(
        snapshot: snapshot,
        target: snapshot.find_node(node_id),
        run_data: run_data,
      )
    end

    def run(node_id:, node_type:, outputs:, status: "success")
      { "node_id" => node_id, "node_type" => node_type, "status" => status, "outputs" => outputs }
    end

    def port(index:, items:)
      { "index" => index, "items" => items }
    end

    def source_run(items:, status: "success", node_id: "set-1")
      run(
        node_id: node_id,
        node_type: "action:set_fields",
        status: status,
        outputs: [port(index: 0, items: items)],
      )
    end
  end
end
