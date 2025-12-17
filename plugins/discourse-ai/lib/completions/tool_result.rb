# frozen_string_literal: true

module DiscourseAi
  module Completions
    class ToolResult
      attr_reader :content, :tool_call

      def initialize(content:, tool_call:)
        @content = content
        @tool_call = tool_call
      end
    end
  end
end
