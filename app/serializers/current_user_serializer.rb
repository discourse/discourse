class CurrentUserSerializer < BasicUserSerializer

  attributes :name,
             :total_unread_notifications,
             :unread_notifications,
             :unread_private_messages,
             :admin?,
             :notification_channel_position,
             :site_flagged_posts_count,
             :moderator?,
             :staff?,
             :reply_count,
             :topic_count,
             :enable_quoting,
             :external_links_in_new_tab,
             :dynamic_favicon,
             :trust_level,
             :can_edit,
             :can_invite_to_forum,
             :no_password,
             :can_delete_account,
             :should_be_redirected_to_top,
             :redirected_to_top_reason,
             :disable_jump_reply,
             :custom_fields,
             :muted_category_ids,
             :dismissed_banner_key

  def include_site_flagged_posts_count?
    object.staff?
  end

  def topic_count
    object.topics.count
  end

  def reply_count
    object.user_stat.topic_reply_count
  end

  def site_flagged_posts_count
    PostAction.flagged_posts_count
  end

  def can_edit
    true
  end

  def can_invite_to_forum
    true
  end

  def include_can_invite_to_forum?
    scope.can_invite_to_forum?
  end

  def no_password
    true
  end

  def include_no_password?
    !object.has_password?
  end

  def include_can_delete_account?
    scope.can_delete_user?(object)
  end

  def can_delete_account
    true
  end

  def include_redirected_to_top_reason?
    object.redirected_to_top_reason.present?
  end

  def custom_fields
    fields = nil
    if SiteSetting.public_user_custom_fields.present?
      fields = SiteSetting.public_user_custom_fields.split('|')
    end
    DiscoursePluginRegistry.serialized_current_user_fields.each do |f|
      fields ||= []
      fields << f
    end

    if fields.present?
      User.custom_fields_for_ids([object.id], fields)[object.id]
    else
      {}
    end
  end

  def muted_category_ids
    @muted_category_ids ||= CategoryUser.where(user_id: object.id,
                                               notification_level: TopicUser.notification_levels[:muted])
                                         .pluck(:category_id)
  end

  def dismissed_banner_key
    object.user_profile.dismissed_banner_key
  end

end
