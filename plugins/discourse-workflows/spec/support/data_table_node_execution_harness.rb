# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableNodeExecutionHarness
    def initialize(example:)
      @example = example
    end

    def execute(configuration:, item: nil, input_items: nil)
      arguments = { configuration: configuration }
      arguments[:item] = item if item
      arguments[:input_items] = input_items if input_items
      @example.execute_node_output(**arguments).first
    end
  end
end
