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
          {}
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
