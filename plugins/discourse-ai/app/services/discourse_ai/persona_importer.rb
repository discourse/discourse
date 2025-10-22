# frozen_string_literal: true

module DiscourseAi
  class PersonaImporter
    class ImportError < StandardError
      attr_reader :conflicts

      def initialize(message, conflicts = {})
        super(message)
        @conflicts = conflicts
      end
    end

    def initialize(json:)
      @data =
        case json
        when String
          JSON.parse(json)
        when Hash
          json
        else
          raise ArgumentError, "Invalid JSON payload"
        end

      validate_payload!
    end

    def import!(overwrite: false)
      ActiveRecord::Base.transaction do
        check_conflicts! unless overwrite

        tool_name_to_id = import_custom_tools(@data["custom_tools"] || [], overwrite: overwrite)
        persona_data = @data["persona"]

        existing_persona = AiPersona.find_by(name: persona_data["name"])

        attrs = {
          description: persona_data["description"],
          system_prompt: persona_data["system_prompt"],
          examples: persona_data["examples"],
          temperature: persona_data["temperature"],
          top_p: persona_data["top_p"],
          response_format: persona_data["response_format"],
          tools: transform_tools_for_import(persona_data["tools"], tool_name_to_id),
        }

        if existing_persona && overwrite
          existing_persona.update!(**attrs)
          existing_persona
        else
          attrs[:name] = persona_data["name"]
          AiPersona.create!(**attrs)
        end
      end
    end

    private

    def validate_payload!
      unless @data.is_a?(Hash) && @data["persona"].is_a?(Hash)
        raise ArgumentError, "Invalid persona export data"
      end
    end

    def check_conflicts!
      conflicts = {}

      persona_name = @data["persona"]["name"]
      conflicts[:persona] = persona_name if AiPersona.exists?(name: persona_name)

      if @data["custom_tools"].present?
        existing_tools = []
        @data["custom_tools"].each do |tool_data|
          tool_name = tool_data["tool_name"] || tool_data["identifier"]
          existing_tools << tool_name if AiTool.exists?(tool_name: tool_name)
        end
        conflicts[:custom_tools] = existing_tools if existing_tools.any?
      end

      if conflicts.any?
        message = build_conflict_message(conflicts)
        raise ImportError.new(message, conflicts)
      end
    end

    def build_conflict_message(conflicts)
      messages = []

      if conflicts[:persona]
        messages << I18n.t("discourse_ai.errors.persona_already_exists", name: conflicts[:persona])
      end

      if conflicts[:custom_tools] && conflicts[:custom_tools].any?
        tools_list = conflicts[:custom_tools].join(", ")
        error =
          I18n.t(
            "discourse_ai.errors.custom_tool_exists",
            names: tools_list,
            count: conflicts[:custom_tools].size,
          )
        messages << error
      end

      messages.join("\n")
    end

    def import_custom_tools(custom_tools, overwrite:)
      return {} if custom_tools.blank?

      custom_tools.each_with_object({}) do |tool_data, map|
        tool_name = tool_data["tool_name"] || tool_data["identifier"]

        if overwrite
          tool = AiTool.find_or_initialize_by(tool_name: tool_name)
        else
          tool = AiTool.new(tool_name: tool_name)
        end

        tool.tap do |t|
          t.name = tool_data["name"]
          t.description = tool_data["description"]
          t.parameters = tool_data["parameters"]
          t.script = tool_data["script"]
          t.summary = tool_data["summary"]
          t.created_by ||= Discourse.system_user
          t.save!
        end

        map[tool.tool_name] = tool.id
      end
    end

    def transform_tools_for_import(tools_config, tool_name_to_id)
      return [] if tools_config.blank?

      tools_config.map do |tool_config|
        if tool_config.is_a?(Array) && tool_config[0].to_s.start_with?("custom-")
          tool_name = tool_config[0].split("-", 2).last
          tool_id = tool_name_to_id[tool_name] || AiTool.find_by(tool_name: tool_name)&.id
          raise ArgumentError, "Custom tool '#{tool_name}' not found" unless tool_id

          ["custom-#{tool_id}", tool_config[1], tool_config[2]]
        else
          tool_config
        end
      end
    end
  end
end
