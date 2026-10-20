# frozen_string_literal: true

module DiscourseWorkflows
  class NodeError < StandardError
    def initialize(message = nil, summary: nil)
      super(message)
      @summary = summary
    end

    # The message without its item or line location, so per-item failures can be grouped.
    def summary
      @summary || message
    end
  end
end
