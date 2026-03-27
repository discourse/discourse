# frozen_string_literal: true

module DiscourseAi
  module PluginInstanceExtension
    # registers an AI feature with its agent, tools, and settings
    #
    #   register_ai_feature(
    #     module_name: :data_explorer,
    #     feature: :query_generation,
    #     klass: DiscourseDataExplorer::AiQueryGenerator,
    #     enabled_by_setting: "data_explorer_ai_queries_enabled",
    #   )
    #
    def register_ai_feature(
      module_name:,
      feature:,
      klass:,
      enabled_by_setting: nil,
      visible: true,
      allowed_group_ids: [Group::AUTO_GROUPS[:staff]]
    )
      reserved = ::DiscourseAi::Agents::Agent::RESERVED_EXTERNAL_IDS[module_name]
      if reserved.nil?
        Rails.logger.warn(
          "register_ai_feature: unknown module #{module_name}, register it in RESERVED_EXTERNAL_IDS",
        )
        return
      end

      feature_config = reserved.dig(:features, feature)
      if feature_config.nil?
        Rails.logger.warn(
          "register_ai_feature: unknown feature #{feature} for #{module_name}, register it in RESERVED_EXTERNAL_IDS",
        )
        return
      end

      module_id = reserved[:module_id]
      agent_id = feature_config[:agent_id]
      area = "ai-features/#{module_name}"

      if DiscoursePluginRegistry.site_setting_areas.exclude?(area)
        DiscoursePluginRegistry.site_setting_areas << area
      end

      if enabled_by_setting.present? && SiteSetting.respond_to?(enabled_by_setting)
        SiteSetting.areas[enabled_by_setting.to_sym] ||= area
      end

      seed_agent(id: agent_id, klass: klass, allowed_group_ids: allowed_group_ids)
      register_tools_for(klass)

      setting_name = :"#{module_name}_#{feature}_agent"
      unless SiteSetting.respond_to?(setting_name)
        SiteSetting.send(
          :setting,
          setting_name,
          agent_id.to_s,
          type: "enum",
          enum: "DiscourseAi::Configuration::AgentEnumerator",
          area: area,
          client: false,
          plugin: directory_name,
        )
      end

      reloadable_patch do
        feature_obj =
          ::DiscourseAi::Configuration::Feature.new(
            feature.to_s,
            setting_name.to_s,
            module_id,
            module_name.to_s,
          )

        ::DiscourseAi::Configuration::Module.register(
          module_name,
          module_id: module_id,
          module_name: module_name,
          features: [feature_obj],
          enabled_by_setting: enabled_by_setting,
          visible:,
        )
      end
    end

    private

    def seed_agent(id:, klass:, allowed_group_ids:)
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

    def register_tools_for(klass)
      instance = klass.new
      instance.tools.each do |tool_klass|
        tool_name = tool_klass.to_s.split("::").last

        next if "DiscourseAi::Agents::Tools::#{tool_name}".safe_constantize
        next if ::DiscourseAi::Agents::Agent.registered_tools.key?(tool_name)

        ::DiscourseAi::Agents::Agent.register_tool(tool_name, tool_klass)
      end
    end
  end
end
