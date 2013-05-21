module ConfigurableUrls

  def tos_path
    SiteSetting.tos_url.blank? ? "#{Discourse::base_uri}/tos" : SiteSetting.tos_url
  end

  def privacy_path
    SiteSetting.privacy_policy_url.blank? ? "#{Discourse::base_uri}/privacy" : SiteSetting.privacy_policy_url
  end

end