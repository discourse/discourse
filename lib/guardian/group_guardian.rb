#mixin for all guardian methods dealing with group permissions
module GroupGuardian

  # Edit authority for groups means membership changes only.
  # Automatic groups are not represented in the GROUP_USERS
  # table and thus do not allow membership changes.
  def can_edit_group?(group)
    (is_admin? || group.users.where('group_users.owner').include?(user)) && !group.automatic
  end

  def can_see_group_messages?(group)
    is_admin? || group.users.include?(user)
  end

end
