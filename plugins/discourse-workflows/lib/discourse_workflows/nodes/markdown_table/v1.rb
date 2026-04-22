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

        MAPPING_MODES = %w[manual auto].freeze

        def self.property_schema
          {
            mapping_mode: {
              type: :options,
              required: true,
              options: MAPPING_MODES,
              default: "manual",
              ui: {
                expression: false,
              },
            },
            columns: {
              type: :collection,
              required: false,
              visible_if: {
                mapping_mode: "manual",
              },
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
          headers, rows =
            if @configuration["mapping_mode"] == "auto"
              auto_table(exec_ctx.input_items)
            else
              configured_table(exec_ctx, @configuration.fetch("columns") { [] })
            end

          return [[wrap({ "markdown" => "" })]] if headers.empty?

          [[wrap({ "markdown" => render_table(headers, rows) })]]
        end

        private

        def auto_table(input_items)
          headers = input_items.flat_map { |item| (item["json"] || {}).keys }.uniq
          rows =
            input_items.map do |item|
              json = item["json"] || {}
              headers.map { |key| format_cell(json[key]) }
            end
          [headers, rows]
        end

        def configured_table(exec_ctx, columns)
          headers = columns.map { |c| c["header"].to_s }
          rows =
            exec_ctx.input_items.map do |item|
              resolved = exec_ctx.get_parameters(item).fetch("columns") { [] }
              resolved.map { |c| format_cell(c["value"]) }
            end
          [headers, rows]
        end

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
