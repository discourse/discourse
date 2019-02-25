#mixin for all guardian methods dealing with tagging permisions
module TagGuardian
  def can_create_tag?
    return is_admin? if SiteSetting.min_trust_to_create_tag.to_s == 'admin'
    return is_staff? if SiteSetting.min_trust_to_create_tag.to_s == 'staff'
    user && SiteSetting.tagging_enabled && user.has_trust_level?(SiteSetting.min_trust_to_create_tag.to_i)
  end

  def can_tag_topics?
    return is_admin? if SiteSetting.min_trust_level_to_tag_topics.to_s == 'admin'
    return is_staff? if SiteSetting.min_trust_level_to_tag_topics.to_s == 'staff'
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

  def hidden_tag_names
    @hidden_tag_names ||= begin
      if SiteSetting.tagging_enabled && !is_staff?
        DiscourseTagging.hidden_tag_names(self)
      else
        []
      end
    end
  end
end
