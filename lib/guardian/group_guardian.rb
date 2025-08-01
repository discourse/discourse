# frozen_string_literal: true

#mixin for all guardian methods dealing with group permissions
module GroupGuardian
  # Creating Method
  def can_create_group?
    is_admin? || (SiteSetting.moderators_manage_categories_and_groups && is_moderator?)
  end

  # Edit authority for groups means membership changes only.
  # Automatic groups are not represented in the GROUP_USERS
  # table and thus do not allow membership changes.
  def can_edit_group?(group)
    !group.automatic &&
      (can_admin_group?(group) || group.users.where("group_users.owner").include?(user))
  end

  def can_admin_group?(group)
    is_admin? ||
      (
        SiteSetting.moderators_manage_categories_and_groups && is_moderator? && can_see?(group) &&
          group.id != Group::AUTO_GROUPS[:admins]
      )
  end

  def can_see_group?(group)
    group.present? && can_see_groups?([group])
  end

  def can_see_group_members?(group)
    return false if group.blank?
    return true if is_admin? || group.members_visibility_level == Group.visibility_levels[:public]
    return true if is_staff? && group.members_visibility_level == Group.visibility_levels[:staff]
    return true if is_staff? && group.members_visibility_level == Group.visibility_levels[:members]
    if authenticated? && group.members_visibility_level == Group.visibility_levels[:logged_on_users]
      return true
    end
    return false if user.blank?

    return false unless membership = GroupUser.find_by(group_id: group.id, user_id: user.id)
    return true if membership.owner

    return false if group.members_visibility_level == Group.visibility_levels[:owners]
    return false if group.members_visibility_level == Group.visibility_levels[:staff]

    true
  end

  def can_see_groups?(groups)
    return false if groups.blank?
    if is_admin? || groups.all? { |g| g.visibility_level == Group.visibility_levels[:public] }
      return true
    end
    if is_staff? && groups.all? { |g| g.visibility_level == Group.visibility_levels[:staff] }
      return true
    end
    if is_staff? && groups.all? { |g| g.visibility_level == Group.visibility_levels[:members] }
      return true
    end
    if authenticated? &&
         groups.all? { |g| g.visibility_level == Group.visibility_levels[:logged_on_users] }
      return true
    end
    return false if user.blank?

    memberships = GroupUser.where(group: groups, user_id: user.id).pluck(:owner)
    return false if memberships.size < groups.size
    return true if memberships.all? # owner of all groups

    return false if groups.all? { |g| g.visibility_level == Group.visibility_levels[:owners] }
    return false if groups.all? { |g| g.visibility_level == Group.visibility_levels[:staff] }

    true
  end

  def can_see_groups_members?(groups)
    return false if groups.blank?

    requested_group_ids = groups.map(&:id) # Can't use pluck, groups could be a regular array
    matching_group_ids =
      Group.where(id: requested_group_ids).members_visible_groups(user).pluck(:id)

    matching_group_ids.sort == requested_group_ids.sort
  end

  def can_see_group_messages?(group)
    return true if is_admin?
    return true if is_moderator? && group.id == Group::AUTO_GROUPS[:moderators]
    return false if user.blank?

    user.in_any_groups?(SiteSetting.personal_message_enabled_groups_map) &&
      group.users.include?(user)
  end

  def can_associate_groups?
    is_admin? && AssociatedGroup.has_provider?
  end
end
