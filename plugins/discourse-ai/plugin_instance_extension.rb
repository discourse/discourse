# frozen_string_literal: true

module DiscourseAi
  module PluginInstanceExtension
    # registers an agent class and seeds/updates its DB record
    #
    #   register_ai_agent(
    #     id: -501,
    #     klass: DiscourseDataExplorer::AiQueryGenerator,
    #     allowed_group_ids: [Group::AUTO_GROUPS[:staff]],
    #   )
    #
    def register_ai_agent(id:, klass:, allowed_group_ids: [Group::AUTO_GROUPS[:staff]])
      ::DiscourseAi::Agents::Agent.register_system_agent(klass, id)

      agent = ::AiAgent.find_by(id: id)
      if agent.nil?
        agent = ::AiAgent.new(id: id)
        agent.system = true
        agent.enabled = true
        agent.allowed_group_ids = allowed_group_ids
      end

      if agent.system
        instance = klass.new
        agent.name = klass.name
        agent.description = klass.description
        agent.system_prompt = instance.system_prompt
        agent.tools = instance.tools.map { |t| [t.to_s.split("::").last, nil, false] }
        agent.temperature = instance.temperature
        agent.save!(validate: false)
      end
    end

    # registers a tool class so agents can discover it
    #
    #   register_ai_tool(DiscourseDataExplorer::Tools::ValidateSql)
    #
    def register_ai_tool(klass)
      tool_name = klass.to_s.split("::").last
      ::DiscourseAi::Agents::Agent.register_tool(tool_name, klass)
    end

    # registers a module + features for the AI features admin page
    #
    #   register_ai_module(
    #     name: "data_explorer",
    #     id: 100,
    #     enabled_by_setting: "data_explorer_enabled",
    #     features: [{ name: "query_generation", agent_id: -501 }],
    #   )
    #
    def register_ai_module(name:, id:, features:, enabled_by_setting: nil, extra_check: nil)
      reloadable_patch do
        feature_objects =
          features.map do |f|
            ::DiscourseAi::Configuration::Feature.new(
              f[:name],
              nil,
              id,
              name,
              agent_ids_lookup: -> { [f[:agent_id]] },
            )
          end

        ::DiscourseAi::Configuration::Module.register(
          name,
          module_id: id,
          module_name: name,
          features: feature_objects,
          enabled_by_setting: enabled_by_setting,
          extra_check: extra_check,
        )
      end
    end
  end
end
