# frozen_string_literal: true

class CurrentUserSerializer < BasicUserSerializer
  include UserTagNotificationsMixin
  include UserSidebarTagsMixin

  attributes :name,
             :unread_notifications,
             :unread_private_messages,
             :unread_high_priority_notifications,
             :all_unread_notifications_count,
             :read_first_notification?,
             :admin?,
             :notification_channel_position,
             :moderator?,
             :staff?,
             :whisperer?,
             :title,
             :any_posts,
             :enable_quoting,
             :enable_defer,
             :external_links_in_new_tab,
             :dynamic_favicon,
             :trust_level,
             :can_send_private_email_messages,
             :can_send_private_messages,
             :can_edit,
             :can_invite_to_forum,
             :no_password,
             :can_delete_account,
             :should_be_redirected_to_top,
             :redirected_to_top,
             :custom_fields,
             :muted_category_ids,
             :indirectly_muted_category_ids,
             :regular_category_ids,
             :tracked_category_ids,
             :watched_first_post_category_ids,
             :watched_category_ids,
             :watched_tags,
             :watching_first_post_tags,
             :tracked_tags,
             :muted_tags,
             :regular_tags,
             :dismissed_banner_key,
             :is_anonymous,
             :reviewable_count,
             :unseen_reviewable_count,
             :read_faq?,
             :automatically_unpin_topics,
             :mailing_list_mode,
             :treat_as_new_topic_start_date,
             :previous_visit_at,
             :seen_notification_id,
             :primary_group_id,
             :flair_group_id,
             :can_create_topic,
             :can_create_group,
             :link_posting_access,
             :external_id,
             :associated_account_ids,
             :top_category_ids,
             :hide_profile_and_presence,
             :groups,
             :second_factor_enabled,
             :ignored_users,
             :title_count_mode,
             :timezone,
             :featured_topic,
             :skip_new_user_tips,
             :seen_popups,
             :do_not_disturb_until,
             :has_topic_draft,
             :can_review,
             :draft_count,
             :default_calendar,
             :bookmark_auto_delete_preference,
             :pending_posts_count,
             :status,
             :sidebar_category_ids,
             :likes_notifications_disabled,
             :grouped_unread_notifications,
             :redesigned_user_menu_enabled,
             :redesigned_user_page_nav_enabled,
             :sidebar_list_destination

  delegate :user_stat, to: :object, private: true
  delegate :any_posts, :draft_count, :pending_posts_count, :read_faq?, to: :user_stat

  def groups
    owned_group_ids = GroupUser.where(user_id: id, owner: true).pluck(:group_id).to_set

    object.visible_groups.pluck(:id, :name, :has_messages).map do |id, name, has_messages|
      group = { id: id, name: name, has_messages: has_messages }
      group[:owner] = true if owned_group_ids.include?(id)
      group
    end
  end

  def link_posting_access
    scope.link_posting_access
  end

  def can_create_topic
    scope.can_create_topic?(nil)
  end

  def can_create_group
    scope.can_create_group?
  end

  def include_can_create_group?
    scope.can_create_group?
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

  def default_calendar
    object.user_option.default_calendar
  end

  def bookmark_auto_delete_preference
    object.user_option.bookmark_auto_delete_preference
  end

  def sidebar_list_destination
    object.user_option.sidebar_list_none_selected? ? SiteSetting.default_sidebar_list_destination : object.user_option.sidebar_list_destination
  end

  def can_send_private_email_messages
    scope.can_send_private_messages_to_email?
  end

  def can_send_private_messages
    scope.can_send_private_message?(Discourse.system_user)
  end

  def can_edit
    true
  end

  def can_invite_to_forum
    scope.can_invite_to_forum?
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
    categories_with_notification_level(:muted)
  end

  def indirectly_muted_category_ids
    CategoryUser.indirectly_muted_category_ids(object)
  end

  def regular_category_ids
    categories_with_notification_level(:regular)
  end

  def tracked_category_ids
    categories_with_notification_level(:tracking)
  end

  def watched_category_ids
    categories_with_notification_level(:watching)
  end

  def watched_first_post_category_ids
    categories_with_notification_level(:watching_first_post)
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

  def can_review
    scope.can_see_review_queue?
  end

  def mailing_list_mode
    object.user_option.mailing_list_mode
  end

  def treat_as_new_topic_start_date
    object.user_option.treat_as_new_topic_start_date
  end

  def skip_new_user_tips
    object.user_option.skip_new_user_tips
  end

  def seen_popups
    object.user_option.seen_popups
  end

  def include_seen_popups?
    SiteSetting.enable_onboarding_popups
  end

  def include_primary_group_id?
    object.primary_group_id.present?
  end

  def external_id
    object&.single_sign_on_record&.external_id
  end

  def include_external_id?
    SiteSetting.enable_discourse_connect
  end

  def associated_account_ids
    values = {}

    object.user_associated_accounts.map do |user_associated_account|
      values[user_associated_account.provider_name] = user_associated_account.provider_uid
    end

    values
  end

  def include_associated_account_ids?
    SiteSetting.include_associated_account_ids
  end

  def second_factor_enabled
    object.totp_enabled? || object.security_keys_enabled?
  end

  def featured_topic
    object.user_profile.featured_topic
  end

  def has_topic_draft
    true
  end

  def include_has_topic_draft?
    Draft.has_topic_draft(object)
  end

  def sidebar_category_ids
    object.sidebar_categories_ids
  end

  def include_sidebar_category_ids?
    SiteSetting.enable_experimental_sidebar_hamburger
  end

  def include_status?
    SiteSetting.enable_user_status && object.has_status?
  end

  def status
    UserStatusSerializer.new(object.user_status, root: false)
  end

  def redesigned_user_menu_enabled
    object.redesigned_user_menu_enabled?
  end

  def likes_notifications_disabled
    object.user_option&.likes_notifications_disabled?
  end

  def include_all_unread_notifications_count?
    redesigned_user_menu_enabled
  end

  def include_grouped_unread_notifications?
    redesigned_user_menu_enabled
  end

  def include_unseen_reviewable_count?
    redesigned_user_menu_enabled
  end

  def redesigned_user_page_nav_enabled
    if SiteSetting.enable_new_user_profile_nav_groups.present?
      object.in_any_groups?(SiteSetting.enable_new_user_profile_nav_groups_map)
    else
      false
    end
  end
end
