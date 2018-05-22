# mixin for all Guardian methods dealing with user permissions
module UserGuardian

  def can_edit_user?(user)
    is_me?(user) || is_staff?
  end

  def can_edit_username?(user)
    return false if (SiteSetting.sso_overrides_username? && SiteSetting.enable_sso?)
    return true if is_staff?
    return false if SiteSetting.username_change_period <= 0
    is_me?(user) && ((user.post_count + user.topic_count) == 0 || user.created_at > SiteSetting.username_change_period.days.ago)
  end

  def can_edit_email?(user)
    return false if (SiteSetting.sso_overrides_email? && SiteSetting.enable_sso?)
    return false unless SiteSetting.email_editable?
    return true if is_staff?
    can_edit?(user)
  end

  def can_edit_name?(user)
    return false if not(SiteSetting.enable_names?)
    return false if (SiteSetting.sso_overrides_name? && SiteSetting.enable_sso?)
    return true if is_staff?
    can_edit?(user)
  end

  def can_see_notifications?(user)
    is_me?(user) || is_admin?
  end

  def can_silence_user?(user)
    user && is_staff? && not(user.staff?)
  end

  def can_unsilence_user?(user)
    user && is_staff?
  end

  def can_delete_user?(user)
    return false if user.nil? || user.admin?
    if is_me?(user)
      user.post_count <= 1
    else
      is_staff? && (user.first_post_created_at.nil? || user.post_count <= 5 || user.first_post_created_at > SiteSetting.delete_user_max_post_age.to_i.days.ago)
    end
  end

  def can_anonymize_user?(user)
    is_staff? && !user.nil? && !user.staff?
  end

  def can_reset_bounce_score?(user)
    user && is_staff?
  end

  def can_check_emails?(user)
    is_admin? || (is_staff? && SiteSetting.show_email_on_profile)
  end

  def restrict_user_fields?(user)
    user.trust_level == TrustLevel[0] && anonymous?
  end

  def can_see_staff_info?(user)
    user && is_staff?
  end

  def can_see_suspension_reason?(user)
    return true unless SiteSetting.hide_suspension_reasons?
    user == @user || is_staff?
  end

  def can_disable_second_factor?(user)
    user && can_administer_user?(user)
  end

end
