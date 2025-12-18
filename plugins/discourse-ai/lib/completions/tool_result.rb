# frozen_string_literal: true

module DiscourseAi
  module Completions
    class ToolResult
      attr_reader :content, :tool_call

      def initialize(content:, tool_call:)
        @content = content
        @tool_call = tool_call
      end

      def to_s
        "ToolResult for #{tool_call.name} (#{tool_call.id}): #{content}"
      end

      def ==(other)
        return nil if !other.is_a?(ToolResult)
        content == other.content && tool_call == other.tool_call
      end
    end
  end
end
