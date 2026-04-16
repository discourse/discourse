# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module MarkdownTable
      class V1 < NodeType
        def self.identifier
          "action:markdown_table"
        end

        def self.icon
          "table-cells"
        end

        def self.color
          "green"
        end

        def self.group
          "data"
        end

        def self.property_schema
          {
            columns: {
              type: :collection,
              required: false,
              item_schema: {
                header: {
                  type: :string,
                  required: true,
                  ui: {
                    expression: false,
                  },
                },
                value: {
                  type: :string,
                  required: true,
                },
              },
            },
          }
        end

        def self.output_schema
          { "markdown" => :string }
        end

        def execute(exec_ctx)
          [[]]
        end
      end
    end
  end
end
