# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class ExternalFeatureSetup
      def self.ensure_setup!
        raw_external_ai_features.each do |config|
          reserved = DiscourseAi::Agents::Agent::RESERVED_EXTERNAL_IDS[config[:module_name]]
          next if reserved.nil?

          feature_config = reserved.dig(:features, config[:feature])
          next if feature_config.nil?

          agent_id = feature_config[:agent_id]

          # create agent picker site setting
          area = "ai-features/#{config[:module_name]}"
          setting_name = :"#{config[:module_name]}_#{config[:feature]}_agent"

          next if SiteSetting.respond_to?(setting_name)
          SiteSetting.send(
            :setting,
            setting_name,
            agent_id.to_s,
            type: "enum",
            enum: "DiscourseAi::Configuration::AgentEnumerator",
            area: area,
            client: false,
          )
        rescue => e
          Rails.logger.warn(
            "Failed to set up AI feature #{config[:module_name]}/#{config[:feature]}: #{e.message}",
          )
        end
      end

      def self.raw_external_ai_features
        DiscoursePluginRegistry._raw_external_ai_features.pluck(:value)
      end
    end
  end
end
