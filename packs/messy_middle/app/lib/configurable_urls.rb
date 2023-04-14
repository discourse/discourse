# frozen_string_literal: true

module ConfigurableUrls
  def faq_path
    SiteSetting.faq_url.blank? ? "#{Discourse.base_path}/faq" : SiteSetting.faq_url
  end

  def tos_path
    SiteSetting.tos_url.blank? ? "#{Discourse.base_path}/tos" : SiteSetting.tos_url
  end

  def privacy_path
    if SiteSetting.privacy_policy_url.blank?
      "#{Discourse.base_path}/privacy"
    else
      SiteSetting.privacy_policy_url
    end
  end
end
