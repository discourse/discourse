# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class NovaTools
        def initialize(tools)
          @raw_tools = tools
        end

        def translated_tools
          return if !@raw_tools.present?

          # note: forced tools are not supported yet toolChoice is always auto
          {
            tools:
              @raw_tools.map do |tool|
                {
                  toolSpec: {
                    name: tool.name,
                    description: tool.description,
                    inputSchema: {
                      json: tool.parameters_json_schema,
                    },
                  },
                }
              end,
          }
        end

        # nativ tools require no system instructions
        def instructions
          ""
        end

        def from_raw_tool_call(raw_message)
          {
            toolUse: {
              toolUseId: raw_message[:id],
              name: raw_message[:name],
              input: JSON.parse(raw_message[:content])["arguments"],
            },
          }
        end

        def from_raw_tool(raw_message)
          {
            toolResult: {
              toolUseId: raw_message[:id],
              content: [{ json: JSON.parse(raw_message[:content]) }],
            },
          }
        end
      end
    end
  end
end
