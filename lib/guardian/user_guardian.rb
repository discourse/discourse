module UserGuardian
  # Can we impersonate this user?
  def can_impersonate?(target)
    target &&

    # You must be an admin to impersonate
    is_admin? &&

    # You may not impersonate other admins
    not(target.admin?)

    # Additionally, you may not impersonate yourself;
    # but the two tests for different admin statuses
    # make it impossible to be the same user.
  end

  def can_ban?(user)
    user && is_staff? && user.regular?
  end
  alias :can_deactivate? :can_ban?

  def can_revoke_admin?(admin)
    can_administer_user?(admin) && admin.admin?
  end

  def can_grant_admin?(user)
    can_administer_user?(user) && not(user.admin?)
  end

  def can_revoke_moderation?(moderator)
    can_administer?(moderator) && moderator.moderator?
  end

  def can_grant_moderation?(user)
    can_administer?(user) && not(user.moderator?)
  end

  def can_grant_title?(user)
    user && is_staff?
  end

  def can_change_trust_level?(user)
    can_administer?(user)
  end

  def can_block_user?(user)
    user && is_staff? && not(user.staff?)
  end

  def can_unblock_user?(user)
    user && is_staff?
  end

  def can_delete_user?(user_to_delete)
    can_administer?(user_to_delete) && user_to_delete.post_count <= 0
  end

  def can_edit_user?(user)
    is_me?(user) || is_staff?
  end
end
