# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Error
      class V1 < NodeType
        OUTPUT_SCHEMA = Schema.document(JSON.parse(<<~JSON)).freeze
          {
            "trigger": { "description": "Trigger data of the failed run, null when an error workflow failed" },
            "workflow": {
              "type": "object",
              "properties": {
                "id": { "type": "string" },
                "name": { "type": "string" }
              }
            },
            "execution": {
              "type": "object",
              "properties": {
                "id": { "type": ["string", "null"] },
                "url": { "type": ["string", "null"] },
                "retryOf": { "type": "null" },
                "error": {
                  "type": "object",
                  "properties": {
                    "message": { "type": "string" },
                    "name": { "type": "string" },
                    "stack": { "type": "string", "x-optional": true }
                  }
                },
                "lastNodeExecuted": { "type": ["string", "null"] },
                "mode": { "type": "string", "enum": ["error", "manual", "webhook", "trigger"] }
              }
            }
          }
        JSON

        description(
          name: "trigger:error",
          version: "1.0",
          defaults: {
            icon: "triangle-exclamation",
            color: "red",
          },
          inputs: [],
          max_nodes: 1,
          output_contracts: [{ schema: OUTPUT_SCHEMA }],
        )

        def initialize(error_data = {}, *)
          super(parameters: {})
          @error_data = error_data.is_a?(Hash) ? error_data : {}
        end

        def valid?
          true
        end

        def output
          @error_data
        end
      end
    end
  end
end
