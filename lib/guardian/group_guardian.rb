#mixin for all guardian methods dealing with group permissions
module GroupGuardian

  # Edit authority for groups means membership changes only.
  # Automatic groups are not represented in the GROUP_USERS
  # table and thus do not allow membership changes.
  def can_edit_group?(group)
    can_log_group_changes?(group) && !group.automatic
  end

  def can_log_group_changes?(group)
    (is_admin? || group.users.where('group_users.owner').include?(user))
  end

  def can_see_group_messages?(group)
    SiteSetting.enable_personal_messages? && (
      is_admin? || group.users.include?(user)
    )
  end
end
