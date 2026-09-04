# frozen_string_literal: true

module DiscourseWorkflows
  class InputContext
    class << self
      def from_node_context(node_context)
        if node_context&.key?("no_items_left")
          { "noItemsLeft" => node_context["no_items_left"] }
        else
          {}
        end
      end
    end
  end
end
