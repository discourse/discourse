# frozen_string_literal: true

module DiscourseAi
  module Completions
    # Measure decoded content, not signatures, encrypted reasoning or provider envelopes.
    class GeneratedOutput
      def initialize
        @text = +""
        @thinking = +""
        @pending_thinking = +""
        @tools = {}
      end

      def <<(part)
        case part
        when String
          @text << part
        when StructuredOutput
          @text.replace(part.to_s)
        when ToolCall
          @tools[part.id] = { name: part.name, arguments: part.parameters }.to_json
        when Thinking
          if part.partial?
            @pending_thinking << part.message.to_s
          else
            @thinking << (part.message.presence || @pending_thinking)
            @pending_thinking.clear
          end
        end
        self
      end

      def size(tokenizer)
        tokenizer.size(@text) + tokenizer.size(@thinking + @pending_thinking) +
          @tools.values.sum { |content| tokenizer.size(content) }
      end
    end
  end
end
