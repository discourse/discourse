# frozen_string_literal: true

module DiscourseAi::AiBot::Sources
  def self.for_user_ids(user_ids)
    return {} if user_ids.blank?

    sources = Hash.new { |hash, user_id| hash[user_id] = [] }

    AiAgent
      .where(user_id: user_ids)
      .order(:id)
      .pluck(:user_id, :id, :name)
      .each { |user_id, id, name| sources[user_id] << source(name, "ai-agents/#{id}/edit") }

    LlmModel
      .where(user_id: user_ids)
      .order(:id)
      .pluck(:user_id, :id, :display_name)
      .each { |user_id, id, name| sources[user_id] << source(name, "ai-llms/#{id}/edit") }

    spam_user_id = SiteSetting.ai_spam_detection_user_id.presence&.to_i
    if spam_user_id && user_ids.include?(spam_user_id)
      sources[spam_user_id] << source(
        I18n.t("discourse_ai.ai_bot.sources.spam_detection"),
        "ai-spam",
      )
    end

    UserCustomField
      .where(user_id: user_ids, name: DiscourseAi::AiBot::HISTORICAL_AI_USER_CUSTOM_FIELD)
      .pluck(:user_id)
      .each do |user_id|
        if sources[user_id].empty?
          sources[user_id] << { label: I18n.t("discourse_ai.ai_bot.sources.historical") }
        end
      end

    sources
  end

  # Admin pages require the plugin, so a disabled plugin keeps the name but drops the link.
  def self.source(label, admin_path)
    if SiteSetting.discourse_ai_enabled
      { label:, url: "#{Discourse.base_path}/admin/plugins/discourse-ai/#{admin_path}" }
    else
      { label:, note: I18n.t("discourse_ai.ai_bot.sources.plugin_disabled") }
    end
  end
  private_class_method :source
end
