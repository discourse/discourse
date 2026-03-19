# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class Mcp < Tool
        class << self
          attr_accessor :server_id_value, :tool_name_value, :schema_value, :function_name_value

          def class_instance(server_id, tool_name, schema, function_name: tool_name)
            klass = Class.new(self)
            klass.server_id_value = server_id
            klass.tool_name_value = tool_name
            klass.schema_value = schema.deep_dup
            klass.function_name_value = function_name
            klass
          end

          def custom?
            true
          end

          def name
            function_name_value
          end

          def tool_name
            tool_name_value
          end

          def server_id
            server_id_value
          end

          def signature
            {
              name: function_name_value,
              description: schema_value["description"].presence || tool_name_value.humanize,
              parameters: convert_json_schema(schema_value["inputSchema"]),
            }
          end

          def placeholder_summary
            schema_value["title"].presence || schema_value.dig("annotations", "title").presence ||
              tool_name_value.humanize
          end

          def placeholder_details
            schema_value["description"].presence || placeholder_summary
          end

          private

          def convert_json_schema(schema)
            return [] if !schema.is_a?(Hash)

            required = Array(schema["required"])
            properties = schema["properties"].is_a?(Hash) ? schema["properties"] : {}

            properties.map do |name, definition|
              type = normalize_type(definition["type"])
              parameter = {
                name: name,
                type: type,
                description: definition["description"].presence || name.humanize,
                required: required.include?(name),
              }

              parameter[:enum] = definition["enum"] if definition["enum"].present?

              if type == "array"
                item_type = normalize_type(definition.dig("items", "type"))
                parameter[:item_type] = item_type if item_type.present?
              end

              parameter
            end
          end

          def normalize_type(type)
            value = Array(type).reject { |item| item == "null" }.first
            return "string" if value.blank?
            return value if value.in?(%w[string integer number boolean array])

            "string"
          end
        end

        def summary
          self.class.placeholder_summary
        end

        def details
          return "" if parameters.blank?

          formatted_parameters
        end

        def invoke
          current_server = server
          current_context = context || DiscourseAi::Agents::BotContext.new(messages: [])

          client = DiscourseAi::Mcp::Client.new(current_server)
          result = invoke_with_session(client, current_context)

          return error_response(normalize_content(result)) if result["isError"]

          { result: normalize_content(result) }
        end

        private

        def invoke_with_session(client, current_context)
          session_id = current_context.mcp_session_for(self.class.server_id)

          if session_id.blank?
            initialized = client.initialize_session
            current_context.store_mcp_session(self.class.server_id, initialized[:session_id])
            session_id = initialized[:session_id]
          end

          client.call_tool(self.class.tool_name, parameters, session_id: session_id)
        rescue DiscourseAi::Mcp::Client::SessionExpiredError
          initialized = client.initialize_session
          current_context.store_mcp_session(self.class.server_id, initialized[:session_id])
          client.call_tool(self.class.tool_name, parameters, session_id: initialized[:session_id])
        end

        def normalize_content(result)
          content = Array(result["content"])

          text =
            content
              .filter_map do |item|
                if item["type"] == "text"
                  item["text"]
                elsif item.present?
                  item.to_json
                end
              end
              .join("\n")

          return text if text.present?
          if result["structuredContent"].present?
            return JSON.pretty_generate(result["structuredContent"])
          end

          result.to_json
        end

        def server
          @server ||= AiMcpServer.find(self.class.server_id)
        end

        def formatted_parameters
          format_parameter_lines(parameters.as_json).join("  \n")
        end

        def format_parameter_lines(value, prefix = nil)
          case value
          when Hash
            value.flat_map do |key, nested_value|
              nested_prefix = prefix.present? ? "#{prefix}.#{key}" : key.to_s
              format_parameter_lines(nested_value, nested_prefix)
            end
          when Array
            return ["#{prefix}: []"] if value.empty?

            if value.all? { |item| scalar_value?(item) }
              ["#{prefix}: #{value.map { |item| format_scalar(item) }.join(", ")}"]
            else
              value.flat_map.with_index do |item, index|
                format_parameter_lines(item, "#{prefix}[#{index}]")
              end
            end
          else
            ["#{prefix}: #{format_scalar(value)}"]
          end
        rescue JSON::GeneratorError, TypeError
          ["#{prefix}: #{value.to_json}"]
        end

        def scalar_value?(value)
          value.nil? || value.is_a?(String) || value.is_a?(Numeric) || value == true ||
            value == false
        end

        def format_scalar(value)
          return "null" if value.nil?
          return value if value.is_a?(String)

          value.to_s
        end
      end
    end
  end
end
