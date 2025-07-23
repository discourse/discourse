# frozen_string_literal: true

module DiscourseAi
  module Features
    def self.feature_config
      [
        {
          id: 1,
          name_ref: "summarization",
          name_key: "discourse_ai.features.summarization.name",
          description_key: "discourse_ai.features.summarization.description",
          persona_setting_name: "ai_summarization_persona",
          enable_setting_name: "ai_summarization_enabled",
        },
        {
          id: 2,
          name_ref: "gists",
          name_key: "discourse_ai.features.gists.name",
          description_key: "discourse_ai.features.gists.description",
          persona_setting_name: "ai_summary_gists_persona",
          enable_setting_name: "ai_summary_gists_enabled",
        },
        {
          id: 3,
          name_ref: "discoveries",
          name_key: "discourse_ai.features.discoveries.name",
          description_key: "discourse_ai.features.discoveries.description",
          persona_setting_name: "ai_bot_discover_persona",
          enable_setting_name: "ai_bot_enabled",
        },
        {
          id: 4,
          name_ref: "discord_search",
          name_key: "discourse_ai.features.discord_search.name",
          description_key: "discourse_ai.features.discord_search.description",
          persona_setting_name: "ai_discord_search_persona",
          enable_setting_name: "ai_discord_search_enabled",
        },
      ]
    end

    def self.features
      feature_config.map do |feature|
        {
          id: feature[:id],
          ref: feature[:name_ref],
          name: I18n.t(feature[:name_key]),
          description: I18n.t(feature[:description_key]),
          persona: AiPersona.find_by(id: SiteSetting.get(feature[:persona_setting_name])),
          persona_setting: {
            name: feature[:persona_setting_name],
            value: SiteSetting.get(feature[:persona_setting_name]),
            type: SiteSetting.type_supervisor.get_type(feature[:persona_setting_name]),
          },
          enable_setting: {
            name: feature[:enable_setting_name],
            value: SiteSetting.get(feature[:enable_setting_name]),
            type: SiteSetting.type_supervisor.get_type(feature[:enable_setting_name]),
          },
        }
      end
    end

    def self.find_feature_by_id(id)
      lookup = features.index_by { |f| f[:id] }
      lookup[id]
    end

    def self.find_feature_by_ref(name_ref)
      lookup = features.index_by { |f| f[:ref] }
      lookup[name_ref]
    end

    def self.find_feature_id_by_ref(name_ref)
      find_feature_by_ref(name_ref)&.dig(:id)
    end

    def self.feature_area(name_ref)
      name_ref = name_ref.to_s if name_ref.is_a?(Symbol)
      find_feature_by_ref(name_ref) || raise(ArgumentError, "Feature not found: #{name_ref}")
      "ai-features/#{name_ref}"
    end
  end
end
