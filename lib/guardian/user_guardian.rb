# frozen_string_literal: true

# mixin for all Guardian methods dealing with user permissions
module UserGuardian

  def can_claim_reviewable_topic?(topic)
    SiteSetting.reviewable_claiming != 'disabled' && can_review_topic?(topic)
  end

  def can_pick_avatar?(user_avatar, upload)
    return false unless self.user
    return true if is_admin?
    # can always pick blank avatar
    return true if !upload
    return true if user_avatar.contains_upload?(upload.id)
    return true if upload.user_id == user_avatar.user_id || upload.user_id == user.id

    UserUpload.exists?(upload_id: upload.id, user_id: user.id)
  end

  def can_edit_user?(user)
    is_me?(user) || is_staff?
  end

  def can_edit_username?(user)
    return false if SiteSetting.sso_overrides_username? && SiteSetting.enable_sso?
    return true if is_staff?
    return false if SiteSetting.username_change_period <= 0
    return false if is_anonymous?
    is_me?(user) && ((user.post_count + user.topic_count) == 0 || user.created_at > SiteSetting.username_change_period.days.ago)
  end

  def can_edit_email?(user)
    return false if SiteSetting.sso_overrides_email? && SiteSetting.enable_sso?
    return false unless SiteSetting.email_editable?
    return true if is_staff?
    return false if is_anonymous?
    can_edit?(user)
  end

  def can_edit_name?(user)
    return false unless SiteSetting.enable_names?
    return false if SiteSetting.sso_overrides_name? && SiteSetting.enable_sso?
    return true if is_staff?
    return false if is_anonymous?
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
      !SiteSetting.enable_sso &&
      !user.has_more_posts_than?(User::MAX_SELF_DELETE_POST_COUNT)
    else
      is_staff? && (
        user.first_post_created_at.nil? ||
          !user.has_more_posts_than?(User::MAX_STAFF_DELETE_POST_COUNT) ||
          user.first_post_created_at > SiteSetting.delete_user_max_post_age.to_i.days.ago
      )
    end
  end

  def can_anonymize_user?(user)
    is_staff? && !user.nil? && !user.staff?
  end

  def can_reset_bounce_score?(user)
    user && is_staff?
  end

  def can_check_emails?(user)
    is_admin? || (is_staff? && SiteSetting.moderators_view_emails)
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

  def can_see_profile?(user)
    return false if user.blank?

    # If a user has hidden their profile, restrict it to them and staff
    if user.user_option.try(:hide_profile_and_presence?)
      return is_me?(user) || is_staff?
    end

    true
  end

  def allowed_user_field_ids(user)
    @allowed_user_field_ids ||= {}
    @allowed_user_field_ids[user.id] ||=
      begin
        if is_staff? || is_me?(user)
          UserField.pluck(:id)
        else
          UserField.where("show_on_profile OR show_on_user_card").pluck(:id)
        end
      end
  end
end
