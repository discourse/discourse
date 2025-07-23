# frozen_string_literal: true

module DiscourseAi::ChatBotHelper
  def toggle_enabled_bots(bots: [])
    models = LlmModel.all
    models = models.where("id not in (?)", bots.map(&:id)) if bots.present?
    models.update_all(enabled_chat_bot: false)

    bots.each { |b| b.update!(enabled_chat_bot: true) }
    DiscourseAi::AiBot::SiteSettingsExtension.enable_or_disable_ai_bots
  end

  def assign_fake_provider_to(setting_name)
    Fabricate(:fake_model).tap do |fake_llm|
      SiteSetting.public_send("#{setting_name}=", "custom:#{fake_llm.id}")
    end
  end

  def assign_persona_to(setting_name, allowed_group_ids)
    Fabricate(:ai_persona, allowed_group_ids: allowed_group_ids).tap do |p|
      SiteSetting.public_send("#{setting_name}=", p.id)
    end
  end
end

RSpec.configure { |config| config.include DiscourseAi::ChatBotHelper }
