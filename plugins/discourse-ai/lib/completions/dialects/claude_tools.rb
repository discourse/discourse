# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class ClaudeTools
        def initialize(tools)
          @raw_tools = tools
        end

        def translated_tools
          raw_tools.map do |t|
            { name: t.name, description: t.description, input_schema: t.parameters_json_schema }
          end
        end

        def instructions
          ""
        end

        def from_raw_tool_call(raw_message)
          call_details = JSON.parse(raw_message[:content], symbolize_names: true)
          result = []

          if raw_message[:thinking] || raw_message[:redacted_thinking_signature]
            if raw_message[:thinking]
              result << {
                type: "thinking",
                thinking: raw_message[:thinking],
                signature: raw_message[:thinking_signature],
              }
            end

            if raw_message[:redacted_thinking_signature]
              result << {
                type: "redacted_thinking",
                data: raw_message[:redacted_thinking_signature],
              }
            end
          end

          tool_call_id = raw_message[:id]

          result << {
            type: "tool_use",
            id: tool_call_id,
            name: raw_message[:name],
            input: call_details[:arguments],
          }

          result
        end

        def from_raw_tool(raw_message)
          [{ type: "tool_result", tool_use_id: raw_message[:id], content: raw_message[:content] }]
        end

        private

        attr_reader :raw_tools
      end
    end
  end
end
