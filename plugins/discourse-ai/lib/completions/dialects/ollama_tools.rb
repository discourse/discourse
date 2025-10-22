# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      # TODO: Define the Tool class to be inherited by all tools.
      class OllamaTools
        def initialize(tools)
          @raw_tools = tools
        end

        def instructions
          "" # Noop. Tools are listed separate.
        end

        def translated_tools
          raw_tools.map do |tool|
            {
              type: "function",
              function: {
                name: tool.name,
                description: tool.description,
                parameters: tool.parameters_json_schema,
              },
            }
          end
        end

        def from_raw_tool_call(raw_message)
          call_details = JSON.parse(raw_message[:content], symbolize_names: true)
          call_details[:name] = raw_message[:name]

          {
            role: "assistant",
            content: nil,
            tool_calls: [{ type: "function", function: call_details }],
          }
        end

        def from_raw_tool(raw_message)
          { role: "tool", content: raw_message[:content], name: raw_message[:name] }
        end

        private

        attr_reader :raw_tools
      end
    end
  end
end
