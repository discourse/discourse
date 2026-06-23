# frozen_string_literal: true

module DiscourseAi
  module Automation
    def self.spam_based_flag_types
      %w[spam spam_silence]
    end

    def self.flag_post_reason(
      reason:,
      llm_response: nil,
      automation_id: nil,
      automation_name: nil,
      base_path: Discourse.base_path
    )
      if automation_context?(automation_id, automation_name)
        I18n.t(
          "discourse_automation.scriptables.llm_triage.flagged_post",
          score_reason:
            spam_score_reason(
              automation_id: automation_id,
              automation_name: automation_name,
              base_path: base_path,
            ),
          response: flag_post_response(reason: reason, llm_response: llm_response),
        )
      else
        I18n.t("discourse_ai.ai_bot.flag_post.reason", reason: reason)
      end
    end

    def self.spam_score_reason(
      automation_id: nil,
      automation_name: nil,
      base_path: Discourse.base_path
    )
      if automation_context?(automation_id, automation_name)
        I18n.t(
          "discourse_automation.scriptables.llm_triage.flagged_post_score_reason",
          base_path: base_path,
          automation_id: automation_id.to_s,
          automation_name: ERB::Util.html_escape(automation_name.to_s),
        )
      else
        I18n.t("discourse_ai.ai_bot.flag_post.score_reason")
      end
    end

    def self.spam_post_action_message(
      reason:,
      llm_response: nil,
      automation_id: nil,
      automation_name: nil,
      base_path: Discourse.base_path
    )
      if automation_context?(automation_id, automation_name)
        flag_post_response(reason: reason, llm_response: llm_response)
      else
        flag_post_reason(
          reason: reason,
          llm_response: llm_response,
          automation_id: automation_id,
          automation_name: automation_name,
          base_path: base_path,
        )
      end
    end

    def self.flag_post_response(reason:, llm_response: nil)
      I18n.t(
        "discourse_automation.scriptables.llm_triage.flagged_post_response",
        llm_response: ERB::Util.html_escape(llm_response.presence || reason),
      )
    end

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
        {
          id: "review_delete_silence",
          translated_name: I18n.t("discourse_automation.ai.flag_types.review_delete_silence"),
        },
        { id: "spam", translated_name: I18n.t("discourse_automation.ai.flag_types.spam") },
        {
          id: "spam_silence",
          translated_name: I18n.t("discourse_automation.ai.flag_types.spam_silence"),
        },
      ]
    end

    def self.available_custom_tools
      available_tools(
        scope: AiTool.where(enabled: true).where("parameters = '[]'::jsonb"),
        description_field: :description,
      )
    end

    def self.available_tools_all
      available_tools(description_field: :summary)
    end

    def self.available_tools(scope: AiTool.where(enabled: true), description_field: :description)
      scope
        .pluck(:id, :name, description_field)
        .map { |id, name, desc| { id: id, translated_name: name, description: desc } }
    end

    def self.available_models
      DB.query_hash(<<~SQL).each { |value_h| value_h["id"] = "#{value_h["id"]}" }
        SELECT display_name AS translated_name, id AS id
        FROM llm_models
      SQL
    end

    def self.available_agent_choices(require_user: true, require_default_llm: true)
      relation = AiAgent.includes(:user)
      relation = relation.where.not(user_id: nil) if require_user
      relation = relation.where.not(default_llm: nil) if require_default_llm
      relation.map do |agent|
        phash = { id: agent.id, translated_name: agent.name, description: agent.name }

        phash[:description] += " (#{agent&.user&.username})" if require_user

        phash
      end
    end

    def self.automation_context?(automation_id, automation_name)
      automation_id.present? && automation_name.present?
    end
    private_class_method :automation_context?, :flag_post_response
  end
end
