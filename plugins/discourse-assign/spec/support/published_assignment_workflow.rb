# frozen_string_literal: true

module PublishedAssignmentWorkflow
  def create_published_assignment_workflow(trigger_node_id:, configuration:, created_by:)
    Fabricate(
      :discourse_workflows_workflow,
      created_by:,
      published: true,
      nodes: [
        {
          "id" => trigger_node_id,
          "type" => "trigger:assigned",
          "typeVersion" => "1.0",
          "name" => trigger_node_id.humanize,
          "position" => {
            "x" => 0,
            "y" => 0,
          },
          "parameters" => configuration.deep_stringify_keys,
          "credentials" => {
          },
        },
      ],
      connections: {
      },
    )
  end
end
