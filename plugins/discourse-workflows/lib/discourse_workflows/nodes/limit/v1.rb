# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Limit
      class V1 < NodeType
        def self.identifier
          "action:limit"
        end

        def self.icon
          "magnifying-glass-minus"
        end

        def self.color_key
          "yellow"
        end

        def self.palette_group_id
          "flow"
        end

        def self.configuration_schema
          {
            max_items: {
              type: :integer,
              required: false,
              default: 10,
            },
            keep: {
              type: :options,
              required: false,
              options: %w[first last],
              default: "first",
            },
          }
        end

        def execute(exec_ctx)
          max = @configuration.fetch("max_items") { 10 }.to_i
          keep = @configuration.fetch("keep") { "first" }

          items =
            if keep == "last"
              exec_ctx.input_items.last(max)
            else
              exec_ctx.input_items.first(max)
            end
          [items]
        end
      end
    end
  end
end
