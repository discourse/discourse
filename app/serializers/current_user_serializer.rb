# frozen_string_literal: true

class CurrentUserSerializer < BasicUserSerializer

  attributes :name,
             :unread_notifications,
             :unread_private_messages,
             :read_first_notification?,
             :admin?,
             :notification_channel_position,
             :moderator?,
             :staff?,
             :title,
             :reply_count,
             :topic_count,
             :enable_quoting,
             :enable_defer,
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
             :custom_fields,
             :muted_category_ids,
             :muted_tag_ids,
             :dismissed_banner_key,
             :is_anonymous,
             :reviewable_count,
             :read_faq,
             :automatically_unpin_topics,
             :mailing_list_mode,
             :previous_visit_at,
             :seen_notification_id,
             :primary_group_id,
             :can_create_topic,
             :link_posting_access,
             :external_id,
             :top_category_ids,
             :hide_profile_and_presence,
             :groups,
             :second_factor_enabled,
             :ignored_users,
             :title_count_mode,
             :timezone,
             :featured_topic

  def groups
    object.visible_groups.pluck(:id, :name).map { |id, name| { id: id, name: name.downcase } }
  end

  def link_posting_access
    scope.link_posting_access
  end

  def can_create_topic
    scope.can_create_topic?(nil)
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

  def hide_profile_and_presence
    object.user_option.hide_profile_and_presence
  end

  def enable_quoting
    object.user_option.enable_quoting
  end

  def enable_defer
    object.user_option.enable_defer
  end

  def external_links_in_new_tab
    object.user_option.external_links_in_new_tab
  end

  def dynamic_favicon
    object.user_option.dynamic_favicon
  end

  def title_count_mode
    object.user_option.title_count_mode
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

  def timezone
    object.user_option.timezone
  end

  def can_send_private_email_messages
    scope.can_send_private_messages_to_email?
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
    CategoryUser.lookup(object, :muted).pluck(:category_id)
  end

  def muted_tag_ids
    TagUser.lookup(object, :muted).pluck(:tag_id)
  end

  def ignored_users
    IgnoredUser.where(user: object.id).joins(:ignored_user).pluck(:username)
  end

  def top_category_ids
    omitted_notification_levels = [CategoryUser.notification_levels[:muted], CategoryUser.notification_levels[:regular]]
    CategoryUser.where(user_id: object.id)
      .where.not(notification_level: omitted_notification_levels)
      .order("
        CASE
          WHEN notification_level = 3 THEN 1
          WHEN notification_level = 2 THEN 2
          WHEN notification_level = 4 THEN 3
        END")
      .pluck(:category_id)
      .slice(0, SiteSetting.header_dropdown_category_count)
  end

  def dismissed_banner_key
    object.user_profile.dismissed_banner_key
  end

  def is_anonymous
    object.anonymous?
  end

  def reviewable_count
    Reviewable.list_for(object).count
  end

  def mailing_list_mode
    object.user_option.mailing_list_mode
  end

  def include_primary_group_id?
    object.primary_group_id.present?
  end

  def external_id
    object&.single_sign_on_record&.external_id
  end

  def include_external_id?
    SiteSetting.enable_sso
  end

  def second_factor_enabled
    object.totp_enabled? || object.security_keys_enabled?
  end

  def featured_topic
    object.user_profile.featured_topic
  end
end
