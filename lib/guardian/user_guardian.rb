# mixin for all Guardian methods dealing with user permissions
module UserGuardian

  def can_edit_user?(user)
    is_me?(user) || is_staff?
  end

  def can_edit_username?(user)
    return false if (SiteSetting.sso_overrides_username? && SiteSetting.enable_sso?)
    return true if is_staff?
    return false if SiteSetting.username_change_period <= 0
    is_me?(user) && (user.post_count == 0 || user.created_at > SiteSetting.username_change_period.days.ago)
  end

  def can_edit_email?(user)
    return false if (SiteSetting.sso_overrides_email? && SiteSetting.enable_sso?)
    return true if is_staff?
    return false unless SiteSetting.email_editable?
    can_edit?(user)
  end

  def can_edit_name?(user)
    return false if not(SiteSetting.enable_names?)
    return false if (SiteSetting.sso_overrides_name? && SiteSetting.enable_sso?)
    return true if is_staff?
    can_edit?(user)
  end

  def can_block_user?(user)
    user && is_staff? && not(user.staff?)
  end

  def can_unblock_user?(user)
    user && is_staff?
  end

  def can_delete_user?(user)
    return false if user.nil?
    return false if user.admin?
    if is_me?(user)
      user.post_count <= 1
    else
      is_staff? && (user.first_post.nil? || user.first_post.created_at > SiteSetting.delete_user_max_post_age.to_i.days.ago)
    end
  end

end
