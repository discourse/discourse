#mixin for all guardian methods dealing with tagging permisions
module TagGuardian
  def can_create_tag?
    user && SiteSetting.tagging_enabled && user.has_trust_level?(SiteSetting.min_trust_to_create_tag.to_i)
  end

  def can_tag_topics?
    user && SiteSetting.tagging_enabled && user.has_trust_level?(SiteSetting.min_trust_level_to_tag_topics.to_i)
  end

  def can_tag_pms?
    is_staff? && SiteSetting.tagging_enabled && SiteSetting.allow_staff_to_tag_pms
  end

  def can_admin_tags?
    is_staff? && SiteSetting.tagging_enabled
  end

  def can_admin_tag_groups?
    is_staff? && SiteSetting.tagging_enabled
  end
end
