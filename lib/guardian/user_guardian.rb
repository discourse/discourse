# frozen_string_literal: true

# mixin for all Guardian methods dealing with user permissions
module UserGuardian
  def can_claim_reviewable_topic?(topic, automatic = false)
    (SiteSetting.reviewable_claiming != "disabled" || automatic) && can_review_topic?(topic)
  end

  def can_pick_avatar?(user_avatar, upload)
    return false unless self.user
    return true if is_admin?
    # can always pick blank avatar
    return true if !upload
    return true if user_avatar.contains_upload?(upload.id)
    return true if upload.user_id == user_avatar.user_id || is_my_own?(upload)

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
    is_me?(user) && user.created_at > SiteSetting.username_change_period.days.ago
  end

  def can_edit_email?(user)
    return false if SiteSetting.auth_overrides_email?
    return false unless SiteSetting.email_editable?
    return true if is_staff?
    return false if is_anonymous?
    can_edit?(user)
  end

  def can_edit_name?(user)
    return false if SiteSetting.auth_overrides_name?
    return true if is_admin?
    return false unless SiteSetting.enable_names?
    return true if is_moderator?
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
      is_staff? &&
        (
          user.first_post_created_at.nil? ||
            !user.has_more_posts_than?(User::MAX_STAFF_DELETE_POST_COUNT) ||
            user.first_post_created_at > SiteSetting.delete_user_max_post_age.to_i.days.ago
        )
    end
  end

  def can_anonymize_user?(user)
    is_staff? && !user.nil? && !user.staff? && !user.email&.ends_with?(UserAnonymizer::EMAIL_SUFFIX)
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
    is_me?(user) || is_staff?
  end

  def can_see_silencing_reason?(user)
    return true unless SiteSetting.hide_silencing_reasons?
    is_me?(user) || is_staff?
  end

  def can_disable_second_factor?(user)
    user && can_administer_user?(user)
  end

  def can_see_user?(_user)
    true
  end

  def public_can_see_profiles?
    !SiteSetting.hide_user_profiles_from_public || !anonymous?
  end

  def can_see_profile?(user)
    return false if user.blank?
    return true if is_me?(user) || is_staff?

    profile_hidden = SiteSetting.allow_users_to_hide_profile && user.user_option&.hide_profile?

    return true if user.staff? && !profile_hidden

    if SiteSetting.hide_new_user_profiles && !SiteSetting.invite_only &&
         !SiteSetting.must_approve_users
      if (user.user_stat.blank? || user.user_stat.post_count == 0) &&
           !user.has_trust_level?(TrustLevel[2])
        return false if anonymous? || !@user.has_trust_level?(TrustLevel[2])
      end

      if anonymous? || !@user.has_trust_level?(TrustLevel[1])
        return user.has_trust_level?(TrustLevel[1]) && !profile_hidden
      end
    end

    !profile_hidden
  end

  def can_see_user_actions?(user, action_types)
    return true if !@user.anonymous? && (is_me?(user) || is_admin?)
    return false if SiteSetting.hide_user_activity_tab?
    (action_types & UserAction.private_types).empty?
  end

  def allowed_user_field_ids(user)
    @allowed_user_field_ids ||= {}

    is_staff_or_is_me = is_staff? || is_me?(user)
    cache_key = is_staff_or_is_me ? :staff_or_me : :other

    @allowed_user_field_ids[cache_key] ||= begin
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
    is_staff? ||
      (
        SiteSetting.enable_category_group_moderation &&
          Reviewable
            .joins(
              "INNER JOIN category_moderation_groups ON category_moderation_groups.category_id = reviewables.category_id",
            )
            .where(
              category_id: allowed_category_ids,
              "category_moderation_groups.group_id": @user.group_users.pluck(:group_id),
            )
            .exists?
      )
  end

  def can_see_summary_stats?(target_user)
    true
  end

  def can_upload_profile_header?(user)
    (is_me?(user) && user.in_any_groups?(SiteSetting.profile_background_allowed_groups_map)) ||
      is_staff?
  end

  def can_upload_user_card_background?(user)
    (is_me?(user) && user.in_any_groups?(SiteSetting.user_card_background_allowed_groups_map)) ||
      is_staff?
  end

  def can_upload_external?
    !ExternalUploadManager.user_banned?(user)
  end

  def can_delete_sso_record?(user)
    SiteSetting.enable_discourse_connect && user && is_admin?
  end

  def can_delete_user_associated_accounts?(user)
    user && is_admin?
  end

  def can_change_tracking_preferences?(user)
    (SiteSetting.allow_changing_staged_user_tracking || !user.staged) && can_edit_user?(user)
  end

  def can_create_theme?
    return false if !is_admin?
    # this modifier is used to further restrict theme creation, it's not
    # possible to use this modifier to open up theme creation permissions (e.g.
    # to non-admins)
    DiscoursePluginRegistry.apply_modifier(:user_guardian_can_create_theme, true, self)
  end
end
