# frozen_string_literal: true

module DiscourseAi::AiBot::Sources
  def self.for_user_ids(user_ids)
    return {} if user_ids.blank?

    sources = Hash.new { |hash, user_id| hash[user_id] = [] }

    AiAgent
      .where(user_id: user_ids)
      .order(:id)
      .pluck(:user_id, :id, :name)
      .each do |user_id, id, name|
        sources[user_id] << {
          label: name,
          url: "#{Discourse.base_path}/admin/plugins/discourse-ai/ai-agents/#{id}/edit",
        }
      end

    LlmModel
      .where(user_id: user_ids)
      .order(:id)
      .pluck(:user_id, :id, :display_name)
      .each do |user_id, id, name|
        sources[user_id] << {
          label: name,
          url: "#{Discourse.base_path}/admin/plugins/discourse-ai/ai-llms/#{id}/edit",
        }
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
end
