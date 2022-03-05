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
    return false if SiteSetting.auth_overrides_username?
    return true if is_staff?
    return false if SiteSetting.username_change_period <= 0
    return false if is_anonymous?
    is_me?(user) && ((user.post_count + user.topic_count) == 0 || user.created_at > SiteSetting.username_change_period.days.ago)
  end

  def can_edit_email?(user)
    return false if SiteSetting.auth_overrides_email?
    return false unless SiteSetting.email_editable?
    return true if is_staff?
    return false if is_anonymous?
    can_edit?(user)
  end

  def can_edit_name?(user)
    return false unless SiteSetting.enable_names?
    return false if SiteSetting.auth_overrides_name?
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
      !SiteSetting.enable_discourse_connect &&
      !user.has_more_posts_than?(SiteSetting.delete_user_self_max_post_count)
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

  def can_merge_user?(user)
    is_admin? && !user.nil? && !user.staff?
  end

  def can_merge_users?(source_user, target_user)
    can_merge_user?(source_user) && !target_user.nil?
  end

  def can_see_warnings?(user)
    user && (is_me?(user) || is_staff?)
  end

  def can_reset_bounce_score?(user)
    user && is_staff?
  end

  def can_check_emails?(user)
    is_admin? || (is_staff? && SiteSetting.moderators_view_emails)
  end

  def can_check_sso_details?(user)
    user && is_admin?
  end

  def restrict_user_fields?(user)
    (user.trust_level == TrustLevel[0] && anonymous?) || !can_see_profile?(user)
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
    return true if !SiteSetting.allow_users_to_hide_profile?

    # If a user has hidden their profile, restrict it to them and staff
    if user.user_option.try(:hide_profile_and_presence?)
      return is_me?(user) || is_staff?
    end

    true
  end

  def can_see_user_actions?(user, action_types)
    return true if !@user.anonymous? && (@user.id == user.id || is_admin?)
    (action_types & UserAction.private_types).empty?
  end

  def allowed_user_field_ids(user)
    @allowed_user_field_ids ||= {}

    is_staff_or_is_me = is_staff? || is_me?(user)
    cache_key = is_staff_or_is_me ? :staff_or_me : :other

    @allowed_user_field_ids[cache_key] ||=
      begin
        if is_staff_or_is_me
          UserField.pluck(:id)
        else
          UserField.where("show_on_profile OR show_on_user_card").pluck(:id)
        end
      end
  end

  def can_feature_topic?(user, topic)
    return false if topic.nil?
    return false if !SiteSetting.allow_featured_topic_on_user_profiles?
    return false if !is_me?(user) && !is_staff?
    return false if !topic.visible
    return false if topic.read_restricted_category? || topic.private_message?
    true
  end

  def can_see_review_queue?
    is_staff? || (
      SiteSetting.enable_category_group_moderation &&
      Reviewable
        .where(reviewable_by_group_id: @user.group_users.pluck(:group_id))
        .where('category_id IS NULL or category_id IN (?)', allowed_category_ids)
        .exists?
    )
  end

  def can_see_summary_stats?(target_user)
    true
  end

  def can_upload_profile_header?(user)
    (is_me?(user) && user.has_trust_level?(SiteSetting.min_trust_level_to_allow_profile_background.to_i)) || is_staff?
  end

  def can_upload_user_card_background?(user)
    (is_me?(user) && user.has_trust_level?(SiteSetting.min_trust_level_to_allow_user_card_background.to_i)) || is_staff?
  end

  def can_upload_external?
    !ExternalUploadManager.user_banned?(user)
  end

  def can_delete_sso_record?(user)
    SiteSetting.enable_discourse_connect && user && is_admin?
  end

  def can_change_tracking_preferences?(user)
    (SiteSetting.allow_changing_staged_user_tracking || !user.staged) && can_edit_user?(user)
  end
end
