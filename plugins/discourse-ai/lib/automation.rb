# frozen_string_literal: true

module DiscourseAi
  module Automation
    def self.flag_types
      [
        { id: "review", translated_name: I18n.t("discourse_automation.ai.flag_types.review") },
        {
          id: "review_hide",
          translated_name: I18n.t("discourse_automation.ai.flag_types.review_hide"),
        },
        {
          id: "review_delete",
          translated_name: I18n.t("discourse_automation.ai.flag_types.review_delete"),
        },
        { id: "spam", translated_name: I18n.t("discourse_automation.ai.flag_types.spam") },
        {
          id: "spam_silence",
          translated_name: I18n.t("discourse_automation.ai.flag_types.spam_silence"),
        },
      ]
    end

    def self.available_custom_tools
      AiTool
        .where(enabled: true)
        .where("parameters = '[]'::jsonb")
        .pluck(:id, :name, :description)
        .map { |id, name, description| { id: id, translated_name: name, description: description } }
    end

    def self.available_models
      DB.query_hash(<<~SQL).each { |value_h| value_h["id"] = "#{value_h["id"]}" }
        SELECT display_name AS translated_name, id AS id
        FROM llm_models
      SQL
    end

    def self.available_persona_choices(require_user: true, require_default_llm: true)
      relation = AiPersona.includes(:user)
      relation = relation.where.not(user_id: nil) if require_user
      relation = relation.where.not(default_llm: nil) if require_default_llm
      relation.map do |persona|
        phash = { id: persona.id, translated_name: persona.name, description: persona.name }

        phash[:description] += " (#{persona&.user&.username})" if require_user

        phash
      end
    end
  end
end
