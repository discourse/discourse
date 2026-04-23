# frozen_string_literal: true

module DiscourseWorkflows
  class InputContext
    def self.from_node_context(node_context)
      return {} unless node_context

      {}.tap do |input_context|
        if node_context.key?("no_items_left")
          input_context["noItemsLeft"] = node_context["no_items_left"]
        end
      end
    end
  end
end
