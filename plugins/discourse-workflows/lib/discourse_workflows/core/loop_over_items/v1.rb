# frozen_string_literal: true

module DiscourseWorkflows
  module Core
    module LoopOverItems
      class V1 < Core::Base
        def self.identifier
          "core:loop_over_items"
        end

        def self.icon
          "arrow-rotate-right"
        end

        def self.color_key
          "brown"
        end

        def self.configuration_schema
          { batch_size: { type: :integer, required: true, default: 1, min: 1 } }
        end

        def self.outputs
          %w[done loop]
        end

        def execute(context, input_items:, node_context:, user: nil, run_as_user: nil)
          batch_size = (@configuration["batch_size"] || 1).to_i
          batch_size = 1 if batch_size < 1

          if node_context["items"].nil?
            execute_first(input_items, node_context, batch_size)
          else
            execute_subsequent(input_items, node_context, batch_size)
          end
        end

        private

        def execute_first(input_items, node_context, batch_size)
          all_items = input_items.dup
          node_context["current_run_index"] = 0
          node_context["max_run_index"] = (all_items.length.to_f / batch_size).ceil
          node_context["processed_items"] = []

          batch = all_items.shift(batch_size)
          node_context["items"] = all_items
          node_context["no_items_left"] = false
          node_context["done"] = false

          { "done" => [], "loop" => batch }
        end

        def execute_subsequent(input_items, node_context, batch_size)
          node_context["processed_items"].concat(input_items)
          node_context["current_run_index"] += 1

          remaining = node_context["items"]
          batch = remaining.shift(batch_size)

          if batch.empty?
            node_context["done"] = true
            node_context["no_items_left"] = true
            { "done" => node_context["processed_items"], "loop" => [] }
          else
            { "done" => [], "loop" => batch }
          end
        end
      end
    end
  end
end
