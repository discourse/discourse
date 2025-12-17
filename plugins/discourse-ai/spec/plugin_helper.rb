# frozen_string_literal: true

module DiscourseAi::ChatBotHelper
  def toggle_enabled_bots(bots: [])
    SiteSetting.ai_bot_enabled = true if bots.any?
    SiteSetting.ai_bot_enabled_llms = bots.map(&:id).join("|")
    DiscourseAi::AiBot::SiteSettingsExtension.enable_or_disable_ai_bots
  end

  def assign_fake_provider_to(setting_name)
    Fabricate(:fake_model).tap do |fake_llm|
      SiteSetting.public_send("#{setting_name}=", "#{fake_llm.id}")
    end
  end

  def assign_persona_to(setting_name, allowed_group_ids)
    Fabricate(:ai_persona, allowed_group_ids: allowed_group_ids).tap do |p|
      SiteSetting.public_send("#{setting_name}=", p.id)
    end
  end
end

RSpec.configure { |config| config.include DiscourseAi::ChatBotHelper }
