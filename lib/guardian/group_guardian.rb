# frozen_string_literal: true

#mixin for all guardian methods dealing with group permissions
module GroupGuardian
  # Creating Method
  def can_create_group?
    is_admin? || (SiteSetting.moderators_manage_groups && is_moderator?)
  end

  # Edit authority for groups means membership changes only.
  # Automatic groups are not represented in the GROUP_USERS
  # table and thus do not allow membership changes.
  def can_edit_group?(group, is_group_owner: nil)
    return false if group.automatic
    return true if can_admin_group?(group, is_group_owner:)
    return is_group_owner unless is_group_owner.nil?

    group.group_users.exists?(user:, owner: true)
  end

  def can_admin_group?(group, is_group_owner: false)
    return true if is_admin?
    return false unless SiteSetting.moderators_manage_groups && is_moderator?
    return false if group.id == Group::AUTO_GROUPS[:admins]
    return true if is_group_owner

    can_see?(group)
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
