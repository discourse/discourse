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

  # Joining a group can copy its primary group, title, trust level and notification
  # defaults onto the new member, so only admins can add other staff accounts to
  # such a group.
  def can_add_group_member?(member, group)
    return true if !member.staff? || is_admin? || is_me?(member)

    !group.primary_group? && group.title.blank? && group.grant_trust_level.to_i.zero? &&
      !group.group_category_notification_defaults.exists? &&
      !group.group_tag_notification_defaults.exists?
  end

  # Leaving a group clears the primary group, flair and title it gave the member and
  # recalculates their trust level, so only admins can remove other staff accounts
  # when that would change them.
  def can_remove_group_member?(member, group)
    return true if !member.staff? || is_admin? || is_me?(member)

    member.primary_group_id != group.id && member.flair_group_id != group.id &&
      (group.title.blank? || member.title != group.title) && group.grant_trust_level.to_i.zero?
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

  def can_use_flair_upload?(upload_id)
    return true if upload_id.blank?
    return true if is_admin?
    return false if user.blank?
    return true if Upload.exists?(id: upload_id, user_id: user.id)

    UserUpload.exists?(upload_id:, user_id: user.id)
  end
end
