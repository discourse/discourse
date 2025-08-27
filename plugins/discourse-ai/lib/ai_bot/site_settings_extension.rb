# frozen_string_literal: true

module DiscourseAi::AiBot::SiteSettingsExtension
  def self.enable_or_disable_ai_bots
    LlmModel.find_each { |llm_model| llm_model.toggle_companion_user }
  end
end
