# frozen_string_literal: true

module DiscourseWorkflows
  module WorkflowExecutionDataBuilder
    def self.run_data_for(
      node_id:,
      node_name:,
      node_type:,
      items:,
      inputs: nil,
      outputs: nil,
      status: "success"
    )
      {
        node_name => [
          {
            "node_id" => node_id.to_s,
            "node_name" => node_name,
            "node_type" => node_type,
            "status" => status,
            "run_index" => 0,
            "inputs" => inputs || [],
            "outputs" =>
              outputs || [{ "index" => 0, "items" => items, "item_count" => items.length }],
          },
        ],
      }
    end
  end
end
