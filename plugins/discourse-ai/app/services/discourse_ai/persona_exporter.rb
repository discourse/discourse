# frozen_string_literal: true

module DiscourseAi
  class PersonaExporter
    def initialize(persona:)
      raise ArgumentError, "Invalid persona provided" if !persona.is_a?(AiPersona)
      @persona = persona
    end

    def export
      serialized_custom_tools = serialize_tools(@persona)
      serialize_persona(@persona, serialized_custom_tools)
    end

    private

    def serialize_tools(ai_persona)
      custom_tool_ids =
        (ai_persona.tools || []).filter_map do |tool_config|
          # A tool config is an array like: ["custom-ID", {options}, force_flag]
          if tool_config.is_a?(Array) && tool_config[0].to_s.start_with?("custom-")
            tool_config[0].split("-", 2).last.to_i
          end
        end

      return [] if custom_tool_ids.empty?

      tools = AiTool.where(id: custom_tool_ids)
      tools.map do |tool|
        {
          identifier: tool.tool_name, # Use tool_name for portability
          name: tool.name,
          description: tool.description,
          tool_name: tool.tool_name,
          parameters: tool.parameters,
          summary: tool.summary,
          script: tool.script,
        }
      end
    end

    def serialize_persona(ai_persona, serialized_custom_tools)
      export_data = {
        meta: {
          version: "1.0",
          exported_at: Time.zone.now.iso8601,
        },
        persona: {
          name: ai_persona.name,
          description: ai_persona.description,
          system_prompt: ai_persona.system_prompt,
          examples: ai_persona.examples,
          temperature: ai_persona.temperature,
          top_p: ai_persona.top_p,
          response_format: ai_persona.response_format,
          tools: transform_tools_for_export(ai_persona.tools, serialized_custom_tools),
        },
        custom_tools: serialized_custom_tools,
      }

      JSON.pretty_generate(export_data)
    end

    def transform_tools_for_export(tools_config, _serialized_custom_tools)
      return [] if tools_config.blank?

      tools_config.map do |tool_config|
        unless tool_config.is_a?(Array) && tool_config[0].to_s.start_with?("custom-")
          next tool_config
        end

        tool_id = tool_config[0].split("-", 2).last.to_i
        tool = AiTool.find_by(id: tool_id)
        next tool_config unless tool

        ["custom-#{tool.tool_name}", tool_config[1], tool_config[2]]
      end
    end
  end
end
