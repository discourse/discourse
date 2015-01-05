#mixin for all guardian methods dealing with group permissions
module GroupGuardian

  # Edit authority for groups means membership changes only.
  # Automatic groups are not represented in the GROUP_USERS
  # table and thus do not allow membership changes.
  def can_edit_group?(group)
    (group.managers.include?(user) || is_admin?) && !group.automatic
  end

end
