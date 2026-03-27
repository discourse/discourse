# frozen_string_literal: true

module DiscourseAi
  class AgentImporter
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

      normalize_legacy_format!
      validate_payload!
    end

    def import!(overwrite: false)
      ActiveRecord::Base.transaction do
        check_conflicts! unless overwrite

        tool_name_to_id = import_custom_tools(@data["custom_tools"] || [], overwrite: overwrite)
        agent_data = @data["agent"]

        existing_agent = AiAgent.find_by(name: agent_data["name"])

        attrs = {
          description: agent_data["description"],
          system_prompt: agent_data["system_prompt"],
          examples: agent_data["examples"],
          temperature: agent_data["temperature"],
          top_p: agent_data["top_p"],
          response_format: agent_data["response_format"],
          tools: transform_tools_for_import(agent_data["tools"], tool_name_to_id),
        }
        mcp_server_assignments = resolve_mcp_server_assignments(agent_data["mcp_servers"])

        if existing_agent && overwrite
          existing_agent.update!(**attrs)
          sync_mcp_server_assignments(existing_agent, mcp_server_assignments)
          existing_agent
        else
          attrs[:name] = agent_data["name"]
          AiAgent
            .create!(**attrs)
            .tap { |agent| sync_mcp_server_assignments(agent, mcp_server_assignments) }
        end
      end
    end

    private

    def normalize_legacy_format!
      if @data.is_a?(Hash) && @data.key?("persona") && !@data.key?("agent")
        @data["agent"] = @data.delete("persona")
      end
    end

    def validate_payload!
      unless @data.is_a?(Hash) && @data["agent"].is_a?(Hash)
        raise ArgumentError, "Invalid agent export data"
      end
    end

    def check_conflicts!
      conflicts = {}

      agent_name = @data["agent"]["name"]
      conflicts[:agent] = agent_name if AiAgent.exists?(name: agent_name)

      if @data["custom_tools"].present?
        existing_tools = []
        @data["custom_tools"].each do |tool_data|
          tool_name = tool_data["tool_name"] || tool_data["identifier"]
          existing_tools << tool_name if AiTool.exists?(tool_name: tool_name)
        end
        conflicts[:custom_tools] = existing_tools if existing_tools.any?
      end

      if @data["agent"]["mcp_servers"].present?
        missing_mcp_servers =
          Array(@data["agent"]["mcp_servers"]).filter_map do |server|
            server_name = extract_mcp_server_name(server)
            server_name if server_name.present? && !AiMcpServer.exists?(name: server_name)
          end
        conflicts[:mcp_servers] = missing_mcp_servers if missing_mcp_servers.any?
      end

      if conflicts.any?
        message = build_conflict_message(conflicts)
        raise ImportError.new(message, conflicts)
      end
    end

    def build_conflict_message(conflicts)
      messages = []

      if conflicts[:agent]
        messages << I18n.t("discourse_ai.errors.agent_already_exists", name: conflicts[:agent])
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

      if conflicts[:mcp_servers] && conflicts[:mcp_servers].any?
        messages << I18n.t(
          "discourse_ai.errors.mcp_server_missing",
          names: conflicts[:mcp_servers].join(", "),
        )
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
          t.secret_contracts = tool_data["secret_contracts"] || []
          t.script = tool_data["script"]
          t.summary = tool_data["summary"]
          t.created_by ||= Discourse.system_user
          t.save!
          t.prune_orphan_bindings! if overwrite
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

    def resolve_mcp_server_assignments(raw_servers)
      return [] if raw_servers.blank?

      server_entries =
        Array(raw_servers).map do |server|
          if server.is_a?(Hash)
            {
              name: server["name"].to_s,
              selected_tool_names:
                Array(server["selected_tool_names"]).filter_map { |name| name.to_s.presence }.uniq,
            }
          else
            { name: server.to_s, selected_tool_names: [] }
          end
        end

      names = server_entries.map { |entry| entry[:name] }
      found = AiMcpServer.where(name: names).index_by(&:name)
      missing = names.reject { |name| found.key?(name) }

      if missing.any?
        raise ImportError.new(
                I18n.t("discourse_ai.errors.mcp_server_missing", names: missing.join(", ")),
                mcp_servers: missing,
              )
      end

      server_entries.map do |entry|
        server = found.fetch(entry[:name])
        selected_tool_names = entry[:selected_tool_names]

        if selected_tool_names.present?
          available_tool_names = server.tools_for_serialization.map { |tool| tool[:name] }
          selected_tool_names &= available_tool_names

          if selected_tool_names.blank?
            raise ImportError.new(
                    I18n.t("discourse_ai.errors.mcp_server_tools_not_found", name: entry[:name]),
                    mcp_servers: [entry[:name]],
                  )
          end
        end

        { id: server.id, selected_tool_names: selected_tool_names.presence }
      end
    end

    def sync_mcp_server_assignments(agent, assignments)
      agent.ai_mcp_server_ids = assignments.map { |assignment| assignment[:id] }

      assignments.each do |assignment|
        agent
          .ai_agent_mcp_servers
          .find_by!(ai_mcp_server_id: assignment[:id])
          .update!(selected_tool_names: assignment[:selected_tool_names])
      end
    end

    def extract_mcp_server_name(server)
      if server.is_a?(Hash)
        server["name"].presence
      else
        server.to_s.presence
      end
    end
  end
end
