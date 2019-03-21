module ConfigurableUrls
  def faq_path
    if SiteSetting.faq_url.blank?
      "#{Discourse.base_uri}/faq"
    else
      SiteSetting.faq_url
    end
  end

  def tos_path
    if SiteSetting.tos_url.blank?
      "#{Discourse.base_uri}/tos"
    else
      SiteSetting.tos_url
    end
  end

  def privacy_path
    if SiteSetting.privacy_policy_url.blank?
      "#{Discourse.base_uri}/privacy"
    else
      SiteSetting.privacy_policy_url
    end
  end
end
