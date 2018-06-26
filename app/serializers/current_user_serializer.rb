require_dependency 'new_post_manager'

class CurrentUserSerializer < BasicUserSerializer

  attributes :name,
             :unread_notifications,
             :unread_private_messages,
             :read_first_notification?,
             :admin?,
             :notification_channel_position,
             :site_flagged_posts_count,
             :moderator?,
             :staff?,
             :title,
             :reply_count,
             :topic_count,
             :enable_quoting,
             :external_links_in_new_tab,
             :dynamic_favicon,
             :trust_level,
             :can_send_private_email_messages,
             :can_edit,
             :can_invite_to_forum,
             :no_password,
             :can_delete_account,
             :should_be_redirected_to_top,
             :redirected_to_top,
             :disable_jump_reply,
             :custom_fields,
             :muted_category_ids,
             :dismissed_banner_key,
             :is_anonymous,
             :post_queue_new_count,
             :show_queued_posts,
             :read_faq,
             :automatically_unpin_topics,
             :mailing_list_mode,
             :previous_visit_at,
             :seen_notification_id,
             :primary_group_id,
             :primary_group_name,
             :can_create_topic,
             :link_posting_access,
             :external_id

  def link_posting_access
    scope.link_posting_access
  end

  def can_create_topic
    scope.can_create_topic?(nil)
  end

  def include_site_flagged_posts_count?
    object.staff?
  end

  def read_faq
    object.user_stat.read_faq?
  end

  def topic_count
    object.user_stat.topic_count
  end

  def reply_count
    object.user_stat.topic_reply_count
  end

  def enable_quoting
    object.user_option.enable_quoting
  end

  def disable_jump_reply
    object.user_option.disable_jump_reply
  end

  def external_links_in_new_tab
    object.user_option.external_links_in_new_tab
  end

  def dynamic_favicon
    object.user_option.dynamic_favicon
  end

  def automatically_unpin_topics
    object.user_option.automatically_unpin_topics
  end

  def should_be_redirected_to_top
    object.user_option.should_be_redirected_to_top
  end

  def redirected_to_top
    object.user_option.redirected_to_top
  end

  def site_flagged_posts_count
    PostAction.flagged_posts_count
  end

  def can_send_private_email_messages
    scope.cand_send_private_messages_to_email?
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

  def include_redirected_to_top?
    object.user_option.redirected_to_top.present?
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
      User.custom_fields_for_ids([object.id], fields)[object.id] || {}
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

  def is_anonymous
    object.anonymous?
  end

  def post_queue_new_count
    QueuedPost.new_count
  end

  def include_post_queue_new_count?
    object.staff?
  end

  def show_queued_posts
    true
  end

  def include_show_queued_posts?
    object.staff? && (NewPostManager.queue_enabled? || QueuedPost.new_count > 0)
  end

  def mailing_list_mode
    object.user_option.mailing_list_mode
  end

  def include_primary_group_id?
    object.primary_group_id.present?
  end

  def primary_group_name
    object.primary_group.name.downcase
  end

  def include_primary_group_name?
    object.primary_group&.name.present?
  end

  def external_id
    object&.single_sign_on_record&.external_id
  end

  def include_external_id?
    SiteSetting.enable_sso
  end
end
