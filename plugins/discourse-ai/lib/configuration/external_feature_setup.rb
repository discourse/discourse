# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class ExternalFeatureSetup
      def self.ensure_setup!
        return if @setup_done
        @setup_done = true

        DiscoursePluginRegistry._raw_ai_features.each do |entry|
          config = entry[:value]
          reserved = DiscourseAi::Agents::Agent::RESERVED_EXTERNAL_IDS[config[:module_name]]
          next if reserved.nil?

          feature_config = reserved.dig(:features, config[:feature])
          next if feature_config.nil?

          agent_id = feature_config[:agent_id]
          klass = config[:klass]

          # register agent class and tools
          DiscourseAi::Agents::Agent.register_system_agent(klass, agent_id)
          klass.new.tools.each do |tool_klass|
            tool_name = tool_klass.to_s.split("::").last
            next if "DiscourseAi::Agents::Tools::#{tool_name}".safe_constantize
            next if DiscourseAi::Agents::Agent.registered_tools.key?(tool_name)
            DiscourseAi::Agents::Agent.register_tool(tool_name, tool_klass)
          end

          # create site settings
          area = "ai-features/#{config[:module_name]}"
          setting_name = :"#{config[:module_name]}_#{config[:feature]}_agent"
          next if SiteSetting.respond_to?(setting_name)

          if DiscoursePluginRegistry.site_setting_areas.exclude?(area)
            DiscoursePluginRegistry.site_setting_areas << area
          end
          if config[:enabled_by_setting].present? &&
               SiteSetting.respond_to?(config[:enabled_by_setting])
            SiteSetting.areas[config[:enabled_by_setting].to_sym] ||= area
          end
          SiteSetting.send(
            :setting,
            setting_name,
            agent_id.to_s,
            type: "enum",
            enum: "DiscourseAi::Configuration::AgentEnumerator",
            area: area,
            client: false,
          )
        end
      end
    end
  end
end
