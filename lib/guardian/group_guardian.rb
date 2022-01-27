# frozen_string_literal: true

#mixin for all guardian methods dealing with group permissions
module GroupGuardian

  # Creating Method
  def can_create_group?
    is_admin? ||
    (
      SiteSetting.moderators_manage_categories_and_groups &&
      is_moderator?
    )
  end

  # Edit authority for groups means membership changes only.
  # Automatic groups are not represented in the GROUP_USERS
  # table and thus do not allow membership changes.
  def can_edit_group?(group)
    !group.automatic &&
      (can_admin_group?(group) || group.users.where('group_users.owner').include?(user))
  end

  def can_admin_group?(group)
    is_admin? ||
    (
      SiteSetting.moderators_manage_categories_and_groups &&
      is_moderator? &&
      can_see?(group) &&
      group.id != Group::AUTO_GROUPS[:admins]
    )
  end

  def can_see_group_messages?(group)
    return true if is_admin?
    return true if is_moderator? && group.id == Group::AUTO_GROUPS[:moderators]

    SiteSetting.enable_personal_messages? && group.users.include?(user)
  end

  def can_associate_groups?
    is_admin? && AssociatedGroup.has_provider?
  end
end
