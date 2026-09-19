# frozen_string_literal: true

module DiscourseWorkflows
  class InputContext
    def self.from_node_context(node_context)
      node_context&.key?("no_items_left") ? { "noItemsLeft" => node_context["no_items_left"] } : {}
    end
  end
end
