# frozen_string_literal: true

module ConfigurableUrls
  def faq_path
    SiteSetting.faq_url.blank? ? "#{Discourse.base_path}/faq" : SiteSetting.faq_url
  end

  def tos_path
    if SiteSetting.tos_url.present?
      SiteSetting.tos_url
    elsif SiteSetting.tos_topic_id > 0 && Topic.exists?(id: SiteSetting.tos_topic_id)
      "#{Discourse.base_path}/tos"
    end
  end

  def privacy_path
    if SiteSetting.privacy_policy_url.present?
      SiteSetting.privacy_policy_url
    elsif SiteSetting.privacy_topic_id > 0 && Topic.exists?(id: SiteSetting.privacy_topic_id)
      "#{Discourse.base_path}/privacy"
    end
  end
end
