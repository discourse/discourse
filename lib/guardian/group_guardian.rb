#mixin for all guardian methods dealing with group permissions
module GroupGuardian

  def can_edit_group?(group)
    is_admin? && !group.automatic
  end

end
