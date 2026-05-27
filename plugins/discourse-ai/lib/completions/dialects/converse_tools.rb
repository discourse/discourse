# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class ConverseTools
        def initialize(tools)
          @raw_tools = tools
        end

        def translated_tools
          return if !@raw_tools.present?

          {
            tools:
              @raw_tools.map do |tool|
                {
                  tool_spec: {
                    name: tool.name,
                    description: tool.description,
                    input_schema: {
                      json: deep_stringify(tool.parameters_json_schema),
                    },
                  },
                }
              end,
          }
        end

        def from_raw_tool_call(raw_message)
          result = []

          provider_info = converse_reasoning(raw_message)
          if provider_info.present?
            if raw_message[:thinking] && provider_info[:signature]
              result << {
                reasoning_content: {
                  reasoning_text: {
                    text: raw_message[:thinking],
                    signature: provider_info[:signature],
                  },
                },
              }
            end

            if provider_info[:redacted_content]
              result << {
                reasoning_content: {
                  redacted_content: provider_info[:redacted_content],
                },
              }
            end
          end

          result << {
            tool_use: {
              tool_use_id: raw_message[:id],
              name: raw_message[:name],
              input: JSON.parse(raw_message[:content])["arguments"],
            },
          }

          result
        end

        def from_raw_tool(raw_message)
          [
            {
              tool_result: {
                tool_use_id: raw_message[:id],
                content: [{ json: JSON.parse(raw_message[:content]) }],
              },
            },
          ]
        end

        private

        def deep_stringify(obj)
          case obj
          when Hash
            obj.transform_keys(&:to_s).transform_values { |v| deep_stringify(v) }
          when Array
            obj.map { |v| deep_stringify(v) }
          when Symbol
            obj.to_s
          else
            obj
          end
        end

        def converse_reasoning(message)
          info = message[:thinking_provider_info]
          return if info.blank?
          info[:bedrock_converse] || info["bedrock_converse"]
        end
      end
    end
  end
end
