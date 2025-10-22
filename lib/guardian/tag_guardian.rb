# frozen_string_literal: true

#mixin for all guardian methods dealing with tagging permissions
module TagGuardian
  def can_see_tag?(_tag)
    true
  end

  def can_create_tag?
    SiteSetting.tagging_enabled && @user.in_any_groups?(SiteSetting.create_tag_allowed_groups_map)
  end

  def can_edit_tag?(_tag = nil)
    SiteSetting.tagging_enabled && @user.in_any_groups?(SiteSetting.edit_tags_allowed_groups_map)
  end

  def can_tag_topics?
    SiteSetting.tagging_enabled && @user.in_any_groups?(SiteSetting.tag_topic_allowed_groups_map)
  end

  def can_tag_pms?
    return false if !SiteSetting.tagging_enabled
    return false if !authenticated?
    return true if @user.is_system_user?

    group_ids = SiteSetting.pm_tags_allowed_for_groups_map
    group_ids.include?(Group::AUTO_GROUPS[:everyone]) ||
      @user.group_users.exists?(group_id: group_ids)
  end

  def can_admin_tags?
    is_staff? && SiteSetting.tagging_enabled
  end

  def can_admin_tag_groups?
    is_staff? && SiteSetting.tagging_enabled
  end

  def hidden_tag_names
    @hidden_tag_names ||=
      begin
        if SiteSetting.tagging_enabled && !is_staff?
          DiscourseTagging.hidden_tag_names(self)
        else
          []
        end
      end
  end
end
