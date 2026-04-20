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
          columns = @configuration.fetch("columns") { [] }
          headers = columns.map { |c| c["header"].to_s }

          return [[wrap({ "markdown" => "" })]] if headers.empty?

          rows =
            exec_ctx.input_items.map do |item|
              resolved = exec_ctx.get_parameters(item).fetch("columns") { [] }
              resolved.map { |c| format_cell(c["value"]) }
            end

          markdown = render_table(headers, rows)
          [[wrap({ "markdown" => markdown })]]
        end

        private

        def render_table(headers, rows)
          lines = []
          lines << row_line(headers)
          lines << row_line(headers.map { "---" })
          rows.each { |cells| lines << row_line(cells) }
          lines.join("\n")
        end

        def row_line(cells)
          "| #{cells.join(" | ")} |"
        end

        def format_cell(value)
          raw =
            if value.nil?
              ""
            elsif value.is_a?(Hash) || value.is_a?(Array)
              JSON.generate(value)
            else
              value.to_s
            end

          sanitize_cell(raw)
        end

        def sanitize_cell(str)
          str.gsub("|", "\\|").gsub(/\r\n|\n/, "<br>")
        end
      end
    end
  end
end
