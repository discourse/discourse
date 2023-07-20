# frozen_string_literal: true

module ConfigurableUrls
  def faq_path
    SiteSetting.faq_url.blank? ? "#{Discourse.base_path}/faq" : SiteSetting.faq_url
  end

  def tos_url
    Discourse.tos_url
  end

  def privacy_policy_url
    Discourse.privacy_policy_url
  end
end
