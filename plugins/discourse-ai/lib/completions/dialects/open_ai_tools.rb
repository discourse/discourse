# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class OpenAiTools
        def initialize(tools, responses_api: false)
          @responses_api = responses_api
          @raw_tools = tools
        end

        def translated_tools
          if @responses_api
            raw_tools.map do |tool|
              definition = {
                type: "function",
                name: tool.name,
                description: tool.description,
                parameters: tool.parameters_json_schema,
              }
              if !tool.json_schema
                definition[:strict] = true
                definition[:parameters] = strict_parameters(definition[:parameters])
              end
              definition
            end
          else
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
        end

        def instructions
          "" # Noop. Tools are listed separate.
        end

        def from_raw_tool_call(raw_message)
          call_details = JSON.parse(raw_message[:content], symbolize_names: true)
          call_details[:arguments] = call_details[:arguments].to_json
          call_details[:name] = raw_message[:name]

          if @responses_api
            provider_data = raw_message[:provider_data] || {}
            open_ai_data =
              provider_data[:open_ai_responses] || provider_data["open_ai_responses"] || {}
            tool_item_id = open_ai_data[:id] || open_ai_data["id"]

            payload = {
              type: "function_call",
              id: tool_item_id,
              call_id: raw_message[:id],
              name: call_details[:name],
              arguments: call_details[:arguments],
            }
            payload.compact
          else
            {
              role: "assistant",
              content: nil,
              tool_calls: [{ type: "function", function: call_details, id: raw_message[:id] }],
            }
          end
        end

        def from_raw_tool(raw_message)
          if @responses_api
            {
              type: "function_call_output",
              call_id: raw_message[:id],
              output: raw_message[:content],
            }
          else
            {
              role: "tool",
              tool_call_id: raw_message[:id],
              content: raw_message[:content],
              name: raw_message[:name],
            }
          end
        end

        private

        attr_reader :raw_tools

        def strict_parameters(schema)
          required = schema.fetch(:required)
          properties =
            schema
              .fetch(:properties)
              .to_h do |name, property|
                if !required.include?(name)
                  # Strict mode requires every key. Null represents an omitted optional argument.
                  property = property.merge(type: [property.fetch(:type), :null])
                  property[:enum] = property[:enum] + [nil] if property[:enum]
                end
                [name, property]
              end

          schema.merge(
            properties: properties,
            required: properties.keys,
            additionalProperties: false,
          )
        end
      end
    end
  end
end
