# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module WorkflowCallTrigger
      class V1 < NodeType
        description(
          name: "trigger:workflow_call",
          version: "1.0",
          defaults: {
            icon: "arrows-turn-to-dots",
            color: "teal",
          },
          inputs: [],
          max_nodes: 1,
          capabilities: {
            manually_triggerable: true,
            provides_current_user: true,
          },
          i18n_scope: "workflow_call_trigger",
        )

        def output
          {}
        end
      end
    end
  end
end
